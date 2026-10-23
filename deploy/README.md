# Deploy: lobby and coturn

Both run as containers on the gvm host (`grafana.r4b2.de`, Hetzner, 91.99.227.111), next to its Caddy, VictoriaMetrics and Grafana. The game connects to `wss://twowards.r4b2.de/ws` (DNS A record to the host, no Cloudflare proxy, since TURN is UDP).

| Piece | Where | Public |
|---|---|---|
| Lobby (`lobby/`) | `two-wards-lobby:8080` on `gvm_default` | `/ws` and `/healthz` through Caddy (TLS) |
| coturn | `two-wards-coturn` on `gvm_default` | 3478 TCP/UDP, relay UDP 49160–49200 |
| Metrics | lobby `/metrics`, coturn `:9641` | no; vector scrapes them into VictoriaMetrics |

CI builds the lobby image on every push and publishes `ghcr.io/yggdrion/two-wards-lobby:latest` (and `:<sha>`) from `main`.

## First setup

1. Firewall: in the Hetzner Cloud console, if the server has a firewall, allow TCP+UDP 3478 and UDP 49160–49200 inbound (443 is already open for Caddy).
2. On the host:

       mkdir -p /root/two-wards && cd /root/two-wards
       # copy docker-compose.yml and turnserver.conf from this folder
       echo "TURN_SECRET=$(openssl rand -hex 32)" > .env && chmod 600 .env
       docker compose up -d

3. In the gvm repo (`/root/gvm`), add the two snippets below, then `docker compose up -d caddy vector` (Caddy fetches the certificate on first request).

## Update

    cd /root/two-wards && docker compose pull && docker compose up -d

## Check

    curl https://twowards.r4b2.de/healthz          # ok
    docker logs two-wards-coturn --tail 20
    # TURN relay with a credential minted like the lobby does:
    U="$(( $(date +%s) + 3600 )):check"; P="$(printf %s "$U" | openssl dgst -sha1 -hmac "$TURN_SECRET" -binary | base64)"
    docker run --rm --network host coturn/coturn:4.18.0 turnutils_uclient -u "$U" -w "$P" -y twowards.r4b2.de

## gvm snippets

Caddyfile, so only the WebSocket and the health check are public:

```
twowards.r4b2.de {
    @public path /ws /healthz
    handle @public {
        reverse_proxy two-wards-lobby:8080
    }
    respond 404
}
```

vector.yaml, a new source that also goes into the `filter_go_metrics` inputs:

```yaml
  two_wards:
    type: prometheus_scrape
    endpoints:
      - "http://two-wards-lobby:8080/metrics"
      - "http://two-wards-coturn:9641/metrics"
    scrape_interval: 30s
```
