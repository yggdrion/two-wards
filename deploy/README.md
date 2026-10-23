# Deploy: lobby and coturn

The server side runs from a clone of this repo on the gvm host (`grafana.r4b2.de`, Hetzner, 91.99.227.111) as its own compose project. It doesn't touch gvm: gvm's Caddy keeps ports 80/443, so the lobby gets its own Caddy on 8443 with a certificate from a Cloudflare DNS challenge. The game connects to `wss://twowards.r4b2.de:8443/ws` (DNS A record to the host, no Cloudflare proxy, since TURN is UDP).

| Service | Public | Notes |
|---|---|---|
| `lobby` (built from `lobby/`) | `/ws`, `/healthz` through `caddy` on 8443 | `/metrics` stays internal |
| `coturn` | 3478 TCP/UDP, relay UDP 49160–49200 | credentials minted by the lobby from `TURN_SECRET` |
| `caddy` (built from `caddy/`) | 8443 | Caddy + Cloudflare DNS module |
| `vector` | — | scrapes lobby and coturn, writes to `vm.r4b2.de` |

Grafana: dashboard "Two Wards server" on grafana.r4b2.de (`/d/two-wards`), source in `grafana/two-wards.json`.

## First setup

    cd /root && git clone https://github.com/yggdrion/two-wards.git
    cd two-wards/deploy
    cp .env.example .env && chmod 600 .env    # fill in the four values, see the comments
    docker compose up -d --build

`CF_API_TOKEN` is a Cloudflare API token with Zone / DNS / Edit on `r4b2.de`. The VictoriaMetrics login is the one gvm's `vector.yaml` uses.

## Update

    cd /root/two-wards && git pull && cd deploy && docker compose up -d --build

## Check

    curl https://twowards.r4b2.de:8443/healthz      # ok
    docker compose logs caddy --tail 20             # certificate obtained
    docker compose logs coturn --tail 20

A TURN credential for manual tests, minted the way the lobby does it:

    . ./.env; U="$(( $(date +%s) + 1800 )):check"
    P="$(printf %s "$U" | openssl dgst -sha1 -hmac "$TURN_SECRET" -binary | base64)"; echo "$U $P"
