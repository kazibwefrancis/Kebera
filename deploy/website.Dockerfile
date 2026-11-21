# Kebera website: a tiny static server for Railway (or any Docker host).
# Build from the repository root:  docker build -f deploy/website.Dockerfile -t kebera-site .
FROM caddy:2-alpine

COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY site/ /srv/
COPY docs/images/*.svg /srv/images/

# Railway sets $PORT; Caddy reads it from the Caddyfile (defaults to 8080 locally).
ENV PORT=8080
EXPOSE 8080
