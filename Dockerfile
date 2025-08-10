# syntax=docker/dockerfile:1
FROM docker.io/library/ubuntu:25.04 AS builder

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    wget make git zlib1g-dev libssl-dev gperf cmake clang libc++-dev libc++abi-dev

USER ubuntu
WORKDIR /home/ubuntu
RUN <<EOT
#!/bin/bash
set -Eeuo pipefail

run() { echo "+ $*"; "$@"; }

run git clone --recursive https://github.com/tdlib/telegram-bot-api.git
run cd telegram-bot-api
run rm -rf build
run mkdir build
run cd build
run CXXFLAGS='-stdlib=libc++' CC=/usr/bin/clang CXX=/usr/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. ..
run cmake --build . --target install -j "$(nproc)"
run strip /home/ubuntu/telegram-bot-api/bin/telegram-bot-api
EOT

FROM docker.io/library/ubuntu:25.04

RUN <<EOT
#!/bin/bash
set -Eeuo pipefail

run() { echo "+ $*"; "$@"; }

run apt-get update
run apt-get upgrade -y
run apt-get clean
run rm -rf /var/lib/apt/lists/*
EOT

COPY --from=builder \
    /home/ubuntu/telegram-bot-api/bin/telegram-bot-api \
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
