#!/bin/sh

BASE_DIR="/etc/local/socat-forward"
CONFIG_FILE="$BASE_DIR/config.json"
RULE_FILE="$BASE_DIR/rules.txt"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
MENU_FILE="$BASE_DIR/socat-forward.sh"
LINK_FILE="/usr/local/bin/sfw"
SYSTEMD_SERVICE="/etc/systemd/system/socat-forward.service"
OPENRC_SERVICE="/etc/init.d/socat-forward"

MENU_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"
STARTER_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh"
ALPINE_SERVICE_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/alpinelinux/socat-forward-service"
DEBIAN_SERVICE_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/debian/socat-forward-service"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

check_installed() {
  [ -f "$CONFIG_FILE" ] && grep -q '"socatScript1"[[:space:]]*:[[:space:]]*1' "$CONFIG_FILE"
}

prompt_uninstall() {
  echo -n "是否卸载并删除服务？(y/n): "
  read ans
  if [ "$ans" = "y" ]; then
    echo -n "是否同时删除规则文件？(y/n): "
    read delrule
    if [ "$delrule" = "y" ]; then
      rm -rf "$BASE_DIR"
    else
      rm -f "$CONFIG_FILE" "$MENU_FILE" "$STARTER_FILE"
    fi
    rm -f "$LINK_FILE"

    if [ -f "$SYSTEMD_SERVICE" ]; then
      systemctl disable socat-forward.service
      systemctl stop socat-forward.service
      rm -f "$SYSTEMD_SERVICE"
      systemctl daemon-reload
    elif [ -f "$OPENRC_SERVICE" ]; then
      rc-update del socat-forward default
      rc-service socat-forward stop
      rm -f "$OPENRC_SERVICE"
    fi
    green "卸载完成"
    exit 0
  else
    green "操作取消"
    exit 0
  fi
}

install_socat() {
  if ! command -v socat >/dev/null 2>&1; then
    echo "socat 未安装，正在安装..."
    if [ -f /etc/debi]()
