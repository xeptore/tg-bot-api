# syntax=docker/dockerfile:1
FROM docker.io/library/alpine:3 AS builder

RUN apk --no-cache add \
    alpine-sdk \
    bash \
    build-base \
    cmake \
    git \
    gperf \
    linux-headers \
    openssl-dev \
    zlib-dev

RUN adduser -D -u 1000 -g 1000 -h /home/nonroot nonroot
USER nonroot
WORKDIR /home/nonroot
RUN <<EOT
#!/bin/bash
set -Eexvuo pipefail

git clone --recursive https://github.com/tdlib/telegram-bot-api.git
cd telegram-bot-api
rm -rf build
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. ..
cmake --build . --target install -j "$(nproc)"
strip /home/nonroot/telegram-bot-api/bin/telegram-bot-api
EOT

FROM docker.io/library/alpine:3

RUN apk --no-cache --update add \
    libstdc++ \
    openssl

COPY --from=builder \
    /home/nonroot/telegram-bot-api/bin/telegram-bot-api \
    /usr/local/bin/telegram-bot-api

# 8081 - default bot api port
# 8082 - default stats port
EXPOSE 8081/tcp 8082/tcp

HEALTHCHECK \
    --interval=5s \
    --timeout=30s \
    --retries=3 \
    CMD nc -z localhost 8081 || exit 1

ENTRYPOINT ["/usr/local/bin/telegram-bot-api"]
