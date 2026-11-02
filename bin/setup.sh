#!/bin/bash

set -o pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ "$(id -u)" != "0" ] && [ "$(uname -m)" == "x86_64" ] && [ "$(uname)" == "Linux" ]; then
    echo "请以 root 用户运行"
    echo "please run with sudo"
    exit
fi

if [ "$(uname -m)" == "x86_64" ] && [ "$(uname)" == "Linux" ]; then
    echo "Device arch: Linux x86_64"
    apt remove *jdk* -y
    apt update -y
    apt upgrade -y
    apt install -y aria2 busybox zip unzip p7zip-full openjdk-21-jre zstd bc android-sdk-libsparse-utils xmlstarlet openssl zipalign curl ca-certificates
    if [ $? -ne 0 ]; then
        echo "安装可能出错，请手动执行：sudo apt install -y aria2 busybox zip unzip p7zip-full openjdk-21-jre zstd bc android-sdk-libsparse-utils xmlstarlet openssl zipalign curl ca-certificates"
    fi
elif [ "$(uname -m)" == "aarch64" ]; then
    echo "Device arch: aarch64"
    apt update -y
    apt upgrade -y
    apt install -y busybox zip unzip p7zip openjdk-17 zipalign zstd xmlstarlet curl ca-certificates
elif [ "$(uname)" == "Darwin" ] && [ "$(uname -m)" == "x86_64" ]; then
    echo "Device arch: MacOS X86_X64"
    brew install aria2 openjdk zstd coreutils gdu gnu-sed gnu-getopt grep xmlstarlet
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
