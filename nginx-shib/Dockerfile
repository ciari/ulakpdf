# nginx + nginx-http-shibboleth + Shibboleth SP (shibd + FCGI helpers)
# Single container so the FCGI sockets stay local.
ARG NGINX_VERSION=1.27.3

FROM debian:bookworm-slim AS builder
ARG NGINX_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git \
        libpcre2-dev zlib1g-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o nginx.tar.gz \
 && tar -xzf nginx.tar.gz \
 && git clone --depth 1 https://github.com/nginx-shib/nginx-http-shibboleth.git \
 && git clone --depth 1 https://github.com/openresty/headers-more-nginx-module.git

RUN cd "nginx-${NGINX_VERSION}" && ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --user=www-data --group=www-data \
        --with-http_ssl_module --with-http_v2_module \
        --with-http_realip_module --with-http_gunzip_module \
        --with-http_gzip_static_module --with-http_auth_request_module \
        --with-pcre --with-pcre-jit \
        --add-dynamic-module=../nginx-http-shibboleth \
        --add-dynamic-module=../headers-more-nginx-module \
 && make -j"$(nproc)" \
 && make install

FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl tini gettext-base \
        libpcre2-8-0 zlib1g libssl3 \
        shibboleth-sp-utils spawn-fcgi \
        openssl xmlsec1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/cache/nginx /var/log/nginx /var/run/shibboleth /etc/nginx/conf.d \
    # Snapshot the package's default /etc/shibboleth so the entrypoint can
    # restore it if a docker volume mount masks it on first boot.
    && cp -a /etc/shibboleth /opt/shibboleth-defaults

# nginx binary + dynamic modules from the builder stage.
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/nginx/modules/ /usr/lib/nginx/modules/
COPY --from=builder /etc/nginx/ /etc/nginx/

# Site config + entrypoint.
COPY conf.d/ /etc/nginx/conf.d/
COPY nginx.conf /etc/nginx/nginx.conf
COPY shibboleth/ /etc/shibboleth-overlay/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
