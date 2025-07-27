#!/bin/sh
url_menu="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"
url_starter="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh"
url_service_debian="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/debian/socat-forward-service"
url_service_alpine="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/alpinelinux/socat-forward-service"

BASE_DIR="/usr/local/socat-forward"
CONFIG_FILE="$BASE_DIR/config.json"
MENU_FILE="$BASE_DIR/socat-forward.sh"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
LINK_FILE="/usr/local/bin/sfw"
SYSTEMD_SERVICE="/etc/systemd/system/socat-forward.service"
OPENRC_SERVICE="/etc/init.d/socat-forward"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
cyan() { printf '\033[36m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

check_command() {
  command -v "$1" >/dev/null 2>&1
}

install_socat() {
  green "➤ 安装 socat..."
  if check_command socat; then
    green "socat 已安装"
    return
  fi
  if [ -f /etc/debian_version ]; then
    apt-get update -qq
    apt-get install -y socat
  elif [ -f /etc/alpine-release ]; then
    apk add --no-cache socat
  else
    red "未知系统，无法安装 socat"
    exit 1
  fi
}

create_dirs() {
  green "➤ 创建程序目录: $BASE_DIR"
  mkdir -p "$BASE_DIR"
}

download_files() {
  green "➤ 下载主脚本和启动器..."
  curl -fsSL -H 'Cache-Control: no-cache' "$url_menu?t=$(date +%s)" -o "$MENU_FILE" || exit 1
  curl -fsSL -H 'Cache-Control: no-cache' "$url_starter?t=$(date +%s)" -o "$STARTER_FILE" || exit 1
  chmod +x "$MENU_FILE" "$STARTER_FILE"
}

install_service() {
  green "➤ 安装开机自启服务..."
  if [ -f /etc/debian_version ]; then
    curl -fsSL "$url_service_debian?t=$(date +%s)" -o "$SYSTEMD_SERVICE" || exit 1
    chmod 644 "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    systemctl enable socat-forward.service
    systemctl start socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    curl -fsSL "$url_service_alpine?t=$(date +%s)" -o "$OPENRC_SERVICE" || exit 1
    chmod +x "$OPENRC_SERVICE"
    rc-update add socat-forward default
    rc-service socat-forward start
  else
    red "未知系统，无法安装服务"
    exit 1
  fi
}

create_link() {
  green "➤ 创建快捷命令: sfw"
  ln -sf "$MENU_FILE" "$LINK_FILE"
}

write_install_status() {
  echo '{"installed":1}' > "$CONFIG_FILE"
}

uninstall_prompt() {
  echo -n "检测到已安装，是否卸载？(y/n): "; read ans
  [ "$ans" = "y" ] || exit 0

  echo -n "是否同时删除已添加的转发规则？(y/n): "; read del_rules
  pkill -f socat 2>/dev/null

  rm -f "$LINK_FILE"
  if [ -f /etc/debian_version ]; then
    systemctl stop socat-forward.service
    systemctl disable socat-forward.service
    rm -f "$SYSTEMD_SERVICE"
    systemctl daemon-reload
  elif [ -f /etc/alpine-release ]; then
    rc-service socat-forward stop
    rc-update del socat-forward default
    rm -f "$OPENRC_SERVICE"
  fi

  if [ "$del_rules" = "y" ]; then
    rm -rf "$BASE_DIR"
  else
    rm -f "$MENU_FILE" "$STARTER_FILE" "$CONFIG_FILE"
  fi
  green "卸载完成"
  exit 0
}

install_main() {
  create_dirs
  install_socat
  [ -f "$CONFIG_FILE" ] && uninstall_prompt
  download_files
  install_service
  create_link
  write_install_status
  green "✔ 安装完成"
  echo "请使用命令" cyan " sfw "  "运行 socat 端口转发管理器"
}

install_main
