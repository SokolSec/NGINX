# Базовый образ
FROM nginx:1.27.2-alpine3.20-perl AS builder

# Установка необходимых пакетов для сборки
RUN apk --update --no-cache add \
        gcc \
        make \
        libc-dev \
        g++ \
        openssl-dev \
        linux-headers \
        pcre-dev \
        zlib-dev \
        libtool \
        automake \
        autoconf \
        libmaxminddb-dev \
        git \
        nano

# Сборка модуля ngx_http_geoip2_module
RUN cd /opt \
    && git clone --depth 1 -b 3.4 --single-branch https://github.com/leev/ngx_http_geoip2_module.git \
    && wget -O - http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz | tar zxfv - \
    && mv /opt/nginx-1.27.2 /opt/nginx \
    && cd /opt/nginx \
    && ./configure --with-compat --add-dynamic-module=/opt/ngx_http_geoip2_module \
    && make modules

# Финальный образ
FROM nginx:1.27.2-alpine3.20-perl

# Копирование модуля из builder
COPY --from=builder /opt/nginx/objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules

# Установка необходимых пакетов
RUN apk --update --no-cache add \
        libmaxminddb \
        certbot \
        nano \
        bash \
        certbot-nginx \
        logrotate \
    && chmod -R 644 /usr/lib/nginx/modules/ngx_http_geoip2_module.so \
    && sed -i '1iload_module \/usr\/lib\/nginx\/modules\/ngx_http_geoip2_module.so;' /etc/nginx/nginx.conf

# Настройка cron для автоматического обновления сертификатов
RUN echo "0 0 1 * * certbot renew --quiet && nginx -s reload" >> /etc/crontabs/root

# Запуск cron и nginx в качестве стартовой команды
CMD ["sh", "-c", "crond && nginx -g 'daemon off;'"]
