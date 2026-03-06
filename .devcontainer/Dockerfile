FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    lua5.1 \
    luarocks \
    ripgrep \
  && ln -sf /usr/bin/lua5.1 /usr/local/bin/lua \
  && ln -sf /usr/bin/luac5.1 /usr/local/bin/luac \
  && rm -rf /var/lib/apt/lists/*
