# syntax=docker/dockerfile:1
FROM docker.io/library/ubuntu:25.04 AS builder
RUN <<EOT
#!/bin/bash
set -Eeuo pipefail

run() { echo "+ $*"; "$@"; }

run apt-get update
run apt-get upgrade -y
run apt-get install -y --no-install-recommends \
  ca-certificates \
  clang \
  cmake \
  gperf \
  git \
  libc++-dev \
  libc++abi-dev \
  libssl-dev \
  make \
  wget \
  zlib1g-dev
EOT
USER ubuntu
WORKDIR /home/ubuntu
RUN <<EOT
#!/bin/bash
set -Eeuo pipefail

run() { echo "+ $*"; "$@"; }

# Build Telegram Bot API
run git clone --recursive https://github.com/tdlib/telegram-bot-api.git
run cd telegram-bot-api
run rm -rf build
run mkdir build
run cd build
run cmake .. \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_CXX_FLAGS='-stdlib=libc++' \
  -DCMAKE_EXE_LINKER_FLAGS='-stdlib=libc++' \
  -DCMAKE_SHARED_LINKER_FLAGS='-stdlib=libc++' \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX:PATH=.. \
  ..
run cmake --build . --target install -j "$(nproc)"
run strip /home/ubuntu/telegram-bot-api/bin/telegram-bot-api

# Compress Executable
upx_version=5.0.2
run workdir="$(pwd)"
run temp_dir="$(mktemp -d)"
run cd "$temp_dir"
run wget -qO- "https://github.com/upx/upx/releases/download/v${upx_version}/upx-${upx_version}-amd64_linux.tar.xz" | tar -xJvf - "upx-${upx_version}-amd64_linux/upx"
run mv "./upx-${upx_version}-amd64_linux/upx" .
run ./upx --no-color --mono --no-progress --ultra-brute --lzma --best --all-methods --all-filters --no-backup "${workdir}/telegram-bot-api"
run ./upx --test "${workdir}/telegram-bot-api"
run cd -
run rm -rfv "${temp_dir}"
EOT

FROM docker.io/library/ubuntu:25.04

RUN <<EOT
#!/bin/bash
set -Eeuo pipefail

run() { echo "+ $*"; "$@"; }

run apt-get update
run apt-get upgrade -y
run apt-get install -y --no-install-recommends \
  ca-certificates \
  libc++1 \
  libc++abi1 \
  openssl
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
