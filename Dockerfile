FROM trafex/php-nginx
USER 0
RUN apk add --no-cache php83-pgsql
USER nobody
COPY --chown=nobody www/ /var/www/html/
