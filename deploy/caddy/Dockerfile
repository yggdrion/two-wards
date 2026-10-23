# Caddy with the Cloudflare DNS module, for certificates without ports 80/443.
FROM caddy:2.11.4-builder AS build
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2.11.4
COPY --from=build /usr/bin/caddy /usr/bin/caddy
