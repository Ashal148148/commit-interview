FROM trafex/php-nginx
USER 0
RUN apk add --no-cache php83-pgsql
COPY nginx/default.conf /etc/nginx/conf.d/
USER nobody
COPY --chown=nobody www/ /var/www/html/
