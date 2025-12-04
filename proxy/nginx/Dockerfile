ARG BASE_IMAGE=ubuntu:jammy
FROM ${BASE_IMAGE} AS builder

ARG NGINX_VERSION=1.26.1
ENV DEBIAND_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y wget build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev libgd-dev libxml2 libxml2-dev uuid-dev unzip

RUN wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz \
 && tar xvfz nginx-$NGINX_VERSION.tar.gz \
 && rm -f nginx-$NGINX_VERSION.tar.get \
 && mv nginx-$NGINX_VERSION nginx \
 && wget -O nginx_upstream_check_module-master.zip  https://codeload.github.com/yaoweibin/nginx_upstream_check_module/zip/refs/heads/master \
 && unzip nginx_upstream_check_module-master.zip  \
 && mv nginx_upstream_check_module-master /nginx_upstream_check_module

RUN cd /nginx \
 && patch -p1 < /nginx_upstream_check_module/check_1.20.1+.patch \
 && ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/etc/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/tmp/nginx/client_temp \
    --http-proxy-temp-path=/tmp/nginx/proxy_temp \
    --http-fastcgi-temp-path=/tmp/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/tmp/nginx/uwsgi_temp \
    --http-scgi-temp-path=/tmp/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt="-g -O2 -ffile-prefix-map=/data/builder/debuild/nginx-$NGINX_VERSION/debian/debuild-base/nginx-$NGINX_VERSION=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC" \
    --with-ld-opt="-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie" \
    --add-module=/nginx_upstream_check_module \
 && make \
 && make install

FROM ${BASE_IMAGE}

RUN addgroup --gid 999 nginx \
 && adduser \
    --uid 999 \
    --gid 999 \
    --no-create-home \
    --shell /bin/bash \
    --disabled-password \
    --gecos "" \
    --quiet \
    nginx


RUN mkdir -p /usr/share/nginx

COPY --from=builder --chown=nginx:nginx /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder --chown=nginx:nginx /etc/nginx/html /usr/share/nginx/html

# COPY --chown=nginx:nginx nginx.conf /etc/nginx/
# COPY --chown=nginx:nginx default.conf /etc/nginx/conf.d/

RUN mkdir -p /tmp/nginx \
 && chown nginx:nginx /tmp/nginx

RUN mkdir -p /etc/nginx/conf.d \
 && chown nginx:nginx /etc/nginx/conf.d

RUN mkdir -p /var/log/nginx \
 && chown nginx:nginx /var/log/nginx

RUN touch /var/log/nginx/access.log \
 && touch /var/log/nginx/error.log \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

RUN chown -R nginx:nginx /var/log/nginx

RUN rm -f /etc/nginx/*.default \
 && rm -f /etc/nginx/*-utf \
 && rm -f /etc/nginx/*-win \
 && rm -rf /etc/nginx/html \

RUN mkdir /app/

ENTRYPOINT /usr/sbin/nginx -g 'daemon off;'
