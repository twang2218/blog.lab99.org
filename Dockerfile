FROM abiosoft/caddy
COPY Caddyfile /etc/Caddyfile
COPY ./public/ /srv/
