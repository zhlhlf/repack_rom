#!/bin/bash

set -o pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
os=$(uname -s)
arch=$(uname -m)

if [ "$os" = "Linux" ] && [ "$(id -u)" != "0" ]; then
    echo "请以 root 用户运行"
    echo "please run with sudo"
    exit 1
fi

if [ "$os" = "Linux" ]; then
    export DEBIAN_FRONTEND=noninteractive
    if [ "$arch" = "x86_64" ]; then
        packages=(aria2 bc unzip p7zip-full openjdk-21-jre zstd android-sdk-libsparse-utils xmlstarlet zipalign curl ca-certificates)
    else
        packages=(aria2 bc unzip p7zip openjdk-17-jre zstd xmlstarlet zipalign curl ca-certificates)
    fi

    echo "Device arch: Linux $arch"
    apt-get update -qq
    if ! apt-get install -y --no-install-recommends "${packages[@]}"; then
        echo "安装失败，请手动执行：apt-get install -y --no-install-recommends ${packages[*]}"
        exit 1
    fi
elif [ "$os" = "Darwin" ]; then
    echo "Device arch: macOS $arch"
    brew install aria2 p7zip openjdk zstd xmlstarlet
else
    echo "不支持的系统: $os $arch"
    exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "正在安装 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "uv 安装失败，请先安装 uv 后重新运行"
    echo "https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi

echo "正在使用 uv 安装 Python 依赖..."
uv sync --project "$project_dir"
