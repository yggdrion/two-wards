# Deploy: lobby and coturn

The server side runs from a clone of this repo on the gvm host (`grafana.r4b2.de`, Hetzner, 91.99.227.111) as its own compose project. gvm's Caddy (ports 80/443) terminates TLS for `twowards.r4b2.de` and proxies to the lobby, which also joins gvm's network `gvm_default` as `two-wards-lobby`. The game connects to `wss://twowards.r4b2.de/ws` (DNS A record to the host, no Cloudflare proxy, since TURN is UDP).

| Service | Public | Notes |
|---|---|---|
| `lobby` (built from `lobby/`) | `/ws`, `/healthz` through gvm's Caddy | `/metrics` stays internal |
| `coturn` | 3478 TCP/UDP, relay UDP 49160–49200 | credentials minted by the lobby from `TURN_SECRET` |
| `vector` | — | scrapes lobby and coturn, writes to `vm.r4b2.de` |

Grafana: dashboard "Two Wards server" on grafana.r4b2.de (`/d/two-wards`), source in `grafana/two-wards.json`.

## First setup

    cd /root && git clone https://github.com/yggdrion/two-wards.git
    cd two-wards/deploy
    cp .env.example .env && chmod 600 .env    # fill in the values, see the comments
    docker compose up -d --build

The VictoriaMetrics login is the one gvm's `vector.yaml` uses. gvm's `Caddyfile` needs this block (then `docker compose restart caddy` in `/root/gvm`):

```
twowards.r4b2.de {
    @public path /ws /healthz
    handle @public {
        reverse_proxy two-wards-lobby:8080
    }
    respond 404
}
```

## Update

    cd /root/two-wards && git pull && cd deploy && docker compose up -d --build

## Check

    curl https://twowards.r4b2.de/healthz          # ok
    docker compose logs coturn --tail 20

A TURN credential for manual tests, minted the way the lobby does it:

    . ./.env; U="$(( $(date +%s) + 1800 )):check"
    P="$(printf %s "$U" | openssl dgst -sha1 -hmac "$TURN_SECRET" -binary | base64)"; echo "$U $P"
