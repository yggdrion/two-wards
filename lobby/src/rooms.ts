// Room codes and signaling relay, without sockets so tests can drive it directly.
//
// Client -> lobby (JSON):
//   {type: "create", protocol}           host opens a room
//   {type: "join", code, protocol}       partner joins by code
//   {type: "signal", data}               WebRTC offer/answer/candidate, relayed verbatim
//   {type: "connected"}                  the peers found each other; the room is done
// Lobby -> client:
//   {type: "created", code, ice}  {type: "joined", ice}  {type: "peer_joined"}
//   {type: "signal", data}  {type: "peer_left"}  {type: "error", reason}
//
// The lobby never looks inside "signal" data and never sees gameplay.

import { createHmac } from "node:crypto";

export interface Peer {
  send(message: string): void;
}

export interface IceServer {
  urls: string[];
  username?: string;
  credential?: string;
}

export interface Config {
  // Must match NetSession.PROTOCOL in the game.
  protocol: number;
  // coturn host for STUN/TURN; empty disables both (local tests).
  turnHost: string;
  // coturn static-auth-secret; empty means STUN only.
  turnSecret: string;
  // How long TURN credentials stay valid.
  turnTtlSeconds: number;
  // Rooms that never start are dropped after this.
  roomTtlMs: number;
}

interface Room {
  code: string;
  host: Peer;
  guest?: Peer;
  createdAt: number;
  started: boolean;
}

// No 0/O, 1/I/L, so codes survive being read out loud.
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ";
const CODE_LENGTH = 4;

export class Lobby {
  readonly rooms = new Map<string, Room>();
  readonly stats = { roomsCreated: 0, joins: 0, messages: 0 };
  private readonly byPeer = new Map<Peer, Room>();

  constructor(
    private readonly config: Config,
    private readonly now: () => number = Date.now,
    private readonly random: () => number = Math.random,
  ) {}

  handle(peer: Peer, raw: string): void {
    this.stats.messages++;
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(raw);
    } catch {
      return send(peer, { type: "error", reason: "bad message" });
    }
    if (typeof msg !== "object" || msg === null) {
      return send(peer, { type: "error", reason: "bad message" });
    }
    switch (msg.type) {
      case "create":
        return this.create(peer, msg.protocol);
      case "join":
        return this.join(peer, String(msg.code ?? "").toUpperCase(), msg.protocol);
      case "signal": {
        const room = this.byPeer.get(peer);
        const other = room && (room.host === peer ? room.guest : room.host);
        if (other) send(other, { type: "signal", data: msg.data });
        return;
      }
      case "connected": {
        const room = this.byPeer.get(peer);
        if (room) room.started = true;
        return;
      }
      default:
        return send(peer, { type: "error", reason: "bad message" });
    }
  }

  // The peer's socket closed. A partner still waiting hears about it; a started room just ends.
  leave(peer: Peer): void {
    const room = this.byPeer.get(peer);
    if (!room) return;
    const other = room.host === peer ? room.guest : room.host;
    if (other && !room.started) send(other, { type: "peer_left" });
    this.remove(room);
  }

  // Drops rooms older than roomTtlMs; the server calls this on a timer.
  sweep(): void {
    const cutoff = this.now() - this.config.roomTtlMs;
    for (const room of this.rooms.values()) {
      if (room.createdAt >= cutoff) continue;
      for (const peer of [room.host, room.guest]) {
        if (peer && !room.started) send(peer, { type: "error", reason: "room expired" });
      }
      this.remove(room);
    }
  }

  // ICE servers for one room, with coturn REST credentials (username "expiry:code").
  iceServers(code: string): IceServer[] {
    const { turnHost, turnSecret, turnTtlSeconds } = this.config;
    if (!turnHost) return [];
    const servers: IceServer[] = [{ urls: [`stun:${turnHost}:3478`] }];
    if (turnSecret) {
      const username = `${Math.floor(this.now() / 1000) + turnTtlSeconds}:${code}`;
      const credential = createHmac("sha1", turnSecret).update(username).digest("base64");
      servers.push({
        urls: [`turn:${turnHost}:3478?transport=udp`, `turn:${turnHost}:3478?transport=tcp`],
        username,
        credential,
      });
    }
    return servers;
  }

  private create(peer: Peer, protocol: unknown): void {
    if (!this.checkProtocol(peer, protocol)) return;
    if (this.byPeer.has(peer)) return send(peer, { type: "error", reason: "already in a room" });
    let code = this.newCode();
    // ponytail: retries on collision; fine while rooms are far fewer than 23^4 = 279841.
    while (this.rooms.has(code)) code = this.newCode();
    const room: Room = { code, host: peer, createdAt: this.now(), started: false };
    this.rooms.set(code, room);
    this.byPeer.set(peer, room);
    this.stats.roomsCreated++;
    send(peer, { type: "created", code, ice: this.iceServers(code) });
  }

  private join(peer: Peer, code: string, protocol: unknown): void {
    if (!this.checkProtocol(peer, protocol)) return;
    if (this.byPeer.has(peer)) return send(peer, { type: "error", reason: "already in a room" });
    const room = this.rooms.get(code);
    if (!room) return send(peer, { type: "error", reason: "no room with that code" });
    if (room.guest) return send(peer, { type: "error", reason: "room is full" });
    room.guest = peer;
    this.byPeer.set(peer, room);
    this.stats.joins++;
    send(peer, { type: "joined", code, ice: this.iceServers(code) });
    send(room.host, { type: "peer_joined" });
  }

  private checkProtocol(peer: Peer, protocol: unknown): boolean {
    if (Number(protocol) === this.config.protocol) return true;
    send(peer, { type: "error", reason: "game version does not match the lobby" });
    return false;
  }

  private remove(room: Room): void {
    this.rooms.delete(room.code);
    this.byPeer.delete(room.host);
    if (room.guest) this.byPeer.delete(room.guest);
  }

  private newCode(): string {
    let code = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
      code += ALPHABET[Math.floor(this.random() * ALPHABET.length)];
    }
    return code;
  }
}

function send(peer: Peer, msg: object): void {
  peer.send(JSON.stringify(msg));
}
