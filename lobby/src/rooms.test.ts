import { describe, expect, test } from "bun:test";
import { createHmac } from "node:crypto";
import { Lobby, type Config, type Peer } from "./rooms";
import { PROTOCOL, startServer } from "./server";

class FakePeer implements Peer {
  inbox: Record<string, unknown>[] = [];
  send(message: string) {
    this.inbox.push(JSON.parse(message));
  }
  last() {
    return this.inbox[this.inbox.length - 1];
  }
}

const config: Config = {
  protocol: 1,
  turnHost: "turn.example",
  turnSecret: "s3cret",
  turnTtlSeconds: 3600,
  roomTtlMs: 60_000,
};

function setup(now = () => 1_000_000) {
  const lobby = new Lobby(config, now);
  const host = new FakePeer();
  const guest = new FakePeer();
  lobby.handle(host, JSON.stringify({ type: "create", protocol: 1 }));
  const code = host.last().code as string;
  return { lobby, host, guest, code };
}

describe("rooms", () => {
  test("create gives a 4-letter code and ICE servers", () => {
    const { lobby, host, code } = setup();
    expect(code).toMatch(/^[A-HJKMNP-Z]{4}$/);
    expect(host.last().type).toBe("created");
    expect(host.last().ice).toHaveLength(2);
    expect(lobby.rooms.size).toBe(1);
  });

  test("join pairs the peers, case-insensitive", () => {
    const { lobby, host, guest, code } = setup();
    lobby.handle(guest, JSON.stringify({ type: "join", code: code.toLowerCase(), protocol: 1 }));
    expect(guest.last()).toMatchObject({ type: "joined", code });
    expect(host.last()).toEqual({ type: "peer_joined" });
  });

  test("signal data is relayed verbatim both ways", () => {
    const { lobby, host, guest, code } = setup();
    lobby.handle(guest, JSON.stringify({ type: "join", code, protocol: 1 }));
    const offer = { kind: "offer", sdp: "v=0..." };
    lobby.handle(host, JSON.stringify({ type: "signal", data: offer }));
    expect(guest.last()).toEqual({ type: "signal", data: offer });
    lobby.handle(guest, JSON.stringify({ type: "signal", data: { kind: "candidate" } }));
    expect(host.last()).toEqual({ type: "signal", data: { kind: "candidate" } });
  });

  test("unknown code, full room and wrong version are refused", () => {
    const { lobby, guest, code } = setup();
    lobby.handle(guest, JSON.stringify({ type: "join", code: "ZZZZ", protocol: 1 }));
    expect(guest.last()).toMatchObject({ type: "error", reason: "no room with that code" });
    lobby.handle(guest, JSON.stringify({ type: "join", code, protocol: 1 }));
    const third = new FakePeer();
    lobby.handle(third, JSON.stringify({ type: "join", code, protocol: 1 }));
    expect(third.last()).toMatchObject({ type: "error", reason: "room is full" });
    const old = new FakePeer();
    lobby.handle(old, JSON.stringify({ type: "create", protocol: 0 }));
    expect(old.last().type).toBe("error");
    lobby.handle(old, "not json");
    expect(old.last()).toMatchObject({ type: "error", reason: "bad message" });
  });

  test("leaving before the game starts tells the partner and frees the room", () => {
    const { lobby, host, guest, code } = setup();
    lobby.handle(guest, JSON.stringify({ type: "join", code, protocol: 1 }));
    lobby.leave(guest);
    expect(host.last()).toEqual({ type: "peer_left" });
    expect(lobby.rooms.size).toBe(0);
  });

  test("a started room ends quietly when the sockets close", () => {
    const { lobby, host, guest, code } = setup();
    lobby.handle(guest, JSON.stringify({ type: "join", code, protocol: 1 }));
    lobby.handle(host, JSON.stringify({ type: "connected" }));
    const seen = guest.inbox.length;
    lobby.leave(host);
    expect(guest.inbox.length).toBe(seen);
    expect(lobby.rooms.size).toBe(0);
  });

  test("rooms expire after the TTL", () => {
    let now = 1_000_000;
    const { lobby, host } = setup(() => now);
    now += config.roomTtlMs - 1;
    lobby.sweep();
    expect(lobby.rooms.size).toBe(1);
    now += 2;
    lobby.sweep();
    expect(lobby.rooms.size).toBe(0);
    expect(host.last()).toMatchObject({ type: "error", reason: "room expired" });
  });

  test("TURN credentials follow the coturn REST scheme", () => {
    const { lobby } = setup();
    const turn = lobby.iceServers("ABCD")[1];
    expect(turn.username).toBe(`${1000 + 3600}:ABCD`);
    expect(turn.credential).toBe(
      createHmac("sha1", "s3cret").update(turn.username!).digest("base64"),
    );
    expect(new Lobby({ ...config, turnHost: "" }).iceServers("ABCD")).toEqual([]);
    expect(new Lobby({ ...config, turnSecret: "" }).iceServers("ABCD")).toHaveLength(1);
  });
});

describe("server", () => {
  test("two websockets pair up and relay, metrics count them", async () => {
    const { server, stop } = startServer(0, { turnHost: "" });
    const url = `ws://127.0.0.1:${server.port}/ws`;
    const open = (ws: WebSocket) => new Promise((r) => (ws.onopen = r));
    const next = (ws: WebSocket) =>
      new Promise<Record<string, unknown>>((r) => (ws.onmessage = (e) => r(JSON.parse(e.data))));
    const host = new WebSocket(url);
    await open(host);
    host.send(JSON.stringify({ type: "create", protocol: PROTOCOL }));
    const created = await next(host);
    expect(created.ice).toEqual([]);
    const guest = new WebSocket(url);
    await open(guest);
    const peerJoined = next(host);
    guest.send(JSON.stringify({ type: "join", code: created.code, protocol: PROTOCOL }));
    expect((await next(guest)).type).toBe("joined");
    expect((await peerJoined).type).toBe("peer_joined");
    const relayed = next(host);
    guest.send(JSON.stringify({ type: "signal", data: { kind: "answer" } }));
    expect(await relayed).toEqual({ type: "signal", data: { kind: "answer" } });
    const metrics = await (await fetch(`http://127.0.0.1:${server.port}/metrics`)).text();
    expect(metrics).toContain("lobby_rooms 1");
    expect(metrics).toContain("lobby_connections 2");
    expect(await (await fetch(`http://127.0.0.1:${server.port}/healthz`)).text()).toBe("ok");
    host.close();
    guest.close();
    stop();
  });
});
