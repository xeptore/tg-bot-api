# syntax=docker/dockerfile:1
FROM docker.io/library/alpine:3 AS builder

RUN apk update && \
    apk upgrade && \
    apk add \
    alpine-sdk \
    bash \
    binutils \
    build-base \
    clang \
    cmake \
    git \
    gperf \
    libc++ \
    libc++-dev \
    libc++abi \
    libc++abi-dev \
    libc-dev \
    linux-headers \
    lld \
    llvm \
    llvm-dev \
    make \
    musl-dev \
    openssl-dev \
    zlib-dev

RUN adduser -D -u 1000 -g 1000 -h /home/nonroot nonroot
USER nonroot
WORKDIR /home/nonroot
RUN <<EOT
#!/bin/bash
set -Eeuo pipefail

source <(wget -qO- https://gist.xeptore.dev/run-nobail.sh)

run git clone --recursive https://github.com/tdlib/telegram-bot-api.git
run cd telegram-bot-api
run rm -rf build
run mkdir build
run cd build
run cmake -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_CXX_FLAGS='-stdlib=libc++' -DCMAKE_EXE_LINKER_FLAGS='-lc++ -lc++abi' -DCMAKE_LINKER=lld -DCMAKE_AR=llvm-ar -DCMAKE_RANLIB=llvm-ranlib -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. ..
run cmake --build . --target install -j "$(nproc)" -v
run strip /home/nonroot/telegram-bot-api/bin/telegram-bot-api
EOT

FROM docker.io/library/alpine:3

RUN apk update && \
    apk upgrade && \
    apk add --no-cache --update \
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
