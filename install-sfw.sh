#!/bin/sh

# ====== 设置下载地址 ======
url_menu="https://your-domain.com/socat-forward.sh"
url_starter="https://your-domain.com/socat-starter.sh"

# ====== 路径定义 ======
BASE_DIR="/etc/local/socat-forward"
CONFIG_FILE="$BASE_DIR/config.json"
RULE_FILE="$BASE_DIR/rules.txt"
MENU_FILE="$BASE_DIR/socat-forward.sh"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
LINK_FILE="/usr/local/bin/sfw"

# ====== 彩色输出函数 ======
green() {
  printf '\033[32m%s\033[0m\n' "$1"
}
red() {
  printf '\033[31m%s\033[0m\n' "$1"
}

check_socat() {
  if command -v socat >/dev/null 2>&1; then
    return
  fi
  echo "未检测到 socat，正在安装..."
  if [ -f /etc/alpine-release ]; then
    apk update && apk add socat
  elif [ -f /etc/debian_version ]; then
    apt update && apt install -y socat
  else
    red "不支持的系统"
    exit 1
  fi
}

check_installed() {
  if [ -f "$CONFIG_FILE" ]; then
    grep '"socatScript1": *1' "$CONFIG_FILE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      green "已安装"
      echo -n "是否卸载？(y/n): "
      read ans
      if [ "$ans" = "y" ]; then
        uninstall
      fi
      exit 0
    fi
  fi
  red "未安装"
  echo -n "是否继续安装？(y/n): "
  read ans
  if [ "]()
