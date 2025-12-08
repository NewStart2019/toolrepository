# ============ 参数定义 ============
ARG NGINX_VERSION=1.27.5
# 最新的 nginx_upstream_check_module 对应的 patch（建议和 nginx 版本匹配）
ARG UPSTREAM_CHECK_VERSION=0.4.0
# 对应 patch 下载地址（淘宝的旧版 patch 已经失效，这里用社区维护的）
ARG UPSTREAM_CHECK_PATCH=https://github.com/yaoweibin/nginx_upstream_check_module/archive/v${UPSTREAM_CHECK_VERSION}.tar.gz

# ============ 基础构建阶段 ============
FROM alpine:3.23.0 AS builder

ARG NGINX_VERSION
ARG UPSTREAM_CHECK_PATCH
ARG TARGETARCH
ARG TARGETVARIANT

# 安装编译依赖
RUN apk add --no-cache \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre2-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    perl-dev \
    patch

WORKDIR /tmp

# 下载 Nginx 源码
RUN curl -L https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar zx \
    && cd nginx-${NGINX_VERSION}

# 下载并解压 nginx_upstream_check_module patch
RUN curl -L ${UPSTREAM_CHECK_PATCH} | tar zx \
    && mv nginx_upstream_check_module-0.4.0 /tmp/nginx-${NGINX_VERSION}/nginx_upstream_check_module

# 给 nginx 源码打 patch（不同的 nginx 版本 patch 方式略有差异，这里使用常用的 -p1）
WORKDIR /tmp/nginx-${NGINX_VERSION}
RUN patch -p1 < nginx_upstream_check_module/check_1.20.1+.patch

# 配置编译参数（根据需要自行增删模块）
# unterminated-string-initialization 关闭 GCC 15 的 QUIC 字符串警告（双保险）
RUN CFLAGS="-Wno-error=unterminated-string-initialization" ./configure \
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
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
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
    --add-module=nginx_upstream_check_module \
    && make -j$(nproc) \
    && make install

# ============ 最终运行镜像 ============
FROM alpine:3.23.0

ARG NGINX_VERSION

# 创建 nginx 用户
RUN addgroup -S nginx && adduser -S -G nginx nginx

# 复制编译好的 nginx
COPY --from=builder --chown=nginx:nginx /etc/nginx/html /usr/share/nginx/html
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
#COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules

# 必要的目录和权限
RUN mkdir -p /var/cache/nginx \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/run \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# 安装运行时依赖
RUN apk add --no-cache \
    pcre2 \
    openssl \
    ca-certificates

EXPOSE 80 443

STOPSIGNAL SIGQUIT

USER nginx

CMD ["nginx", "-g", "daemon off;"]