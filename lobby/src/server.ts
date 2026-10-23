// Lobby/signaling server: WebSocket on /ws, health on /healthz, Prometheus metrics on /metrics.
// Environment: PORT (8080), TURN_HOST (empty = no STUN/TURN), TURN_SECRET (empty = STUN only).

import type { ServerWebSocket } from "bun";
import { Lobby, type Config } from "./rooms";

export const PROTOCOL = 1;

export function startServer(port: number, config: Partial<Config> = {}) {
  const lobby = new Lobby({
    protocol: PROTOCOL,
    turnHost: process.env.TURN_HOST ?? "",
    turnSecret: process.env.TURN_SECRET ?? "",
    turnTtlSeconds: 6 * 3600,
    roomTtlMs: 10 * 60 * 1000,
    ...config,
  });
  const sweeper = setInterval(() => lobby.sweep(), 30_000);
  let sockets = 0;

  const server = Bun.serve({
    port,
    fetch(req, srv) {
      const path = new URL(req.url).pathname;
      if (path === "/ws") {
        return srv.upgrade(req) ? undefined : new Response("expected websocket", { status: 400 });
      }
      if (path === "/healthz") return new Response("ok");
      if (path === "/metrics") return new Response(metrics(lobby, sockets));
      return new Response("not found", { status: 404 });
    },
    websocket: {
      // Signaling is a few small messages per game.
      maxPayloadLength: 64 * 1024,
      open() {
        sockets++;
      },
      message(ws: ServerWebSocket<unknown>, message) {
        lobby.handle(ws, String(message));
      },
      close(ws: ServerWebSocket<unknown>) {
        sockets--;
        lobby.leave(ws);
      },
    },
  });

  return {
    server,
    lobby,
    stop() {
      clearInterval(sweeper);
      server.stop(true);
    },
  };
}

function metrics(lobby: Lobby, sockets: number): string {
  const lines = [
    "# TYPE lobby_rooms gauge",
    `lobby_rooms ${lobby.rooms.size}`,
    "# TYPE lobby_connections gauge",
    `lobby_connections ${sockets}`,
    "# TYPE lobby_rooms_created_total counter",
    `lobby_rooms_created_total ${lobby.stats.roomsCreated}`,
    "# TYPE lobby_joins_total counter",
    `lobby_joins_total ${lobby.stats.joins}`,
    "# TYPE lobby_messages_total counter",
    `lobby_messages_total ${lobby.stats.messages}`,
  ];
  return lines.join("\n") + "\n";
}

if (import.meta.main) {
  const { server } = startServer(Number(process.env.PORT ?? 8080));
  console.log(`lobby listening on :${server.port}`);
}
