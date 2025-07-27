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

green() { printf '\033[32m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }
cyan() { printf '\033[36m%s\033[0m' "$1"; }

check_command() {
  command -v "$1" >/dev/null 2>&1
}

install_socat() {
  if check_command socat; then
    green "socat 已安装\n"
    return
  fi
  if [ -f /etc/debian_version ]; then
    echo "检测到 Debian 系统，开始安装 socat..."
    apt-get update -qq
    apt-get install -y socat
  elif [ -f /etc/alpine-release ]; then
    echo "检测到 Alpine Linux 系统，开始安装 socat..."
    apk add --no-cache socat
  else
    red "未知系统，无法安装 socat"
    exit 1
  fi
  green "socat 安装完成\n"
}

create_dirs() {
  [ -d "$BASE_DIR" ] || mkdir -p "$BASE_DIR"
}

download_files() {
  echo "下载主脚本..."
  curl -fsSL -H 'Cache-Control: no-cache' "$url_menu?t=$(date +%s)" -o "$MENU_FILE" || exit 1
  echo "下载启动器脚本..."
  curl -fsSL -H 'Cache-Control: no-cache' "$url_starter?t=$(date +%s)" -o "$STARTER_FILE" || exit 1
  chmod +x "$MENU_FILE" "$STARTER_FILE"
}

install_service() {
  if [ -f /etc/debian_version ]; then
    echo "安装 systemd 服务..."
    curl -fsSL -H 'Cache-Control: no-cache' "$url_service_debian?t=$(date +%s)" -o "$SYSTEMD_SERVICE" || exit 1
    chmod 644 "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    systemctl enable socat-forward.service
    systemctl start socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    echo "安装 OpenRC 服务..."
    curl -fsSL -H 'Cache-Control: no-cache' "$url_service_alpine?t=$(date +%s)" -o "$OPENRC_SERVICE" || exit 1
    chmod +x "$OPENRC_SERVICE"
    rc-update add socat-forward default
    rc-service socat-forward start
  else
    red "未知系统，无法安装服务"
    exit 1
  fi
}

create_link() {
  ln -sf "$MENU_FILE" "$LINK_FILE"
}

read_install_status() {
  [ -f "$CONFIG_FILE" ] && grep -q '"socatScript1":1' "$CONFIG_FILE"
}

write_install_status() {
  echo '{"socatScript1":1}' > "$CONFIG_FILE"
}

uninstall_prompt() {
  echo -n "检测到已安装，是否卸载？(y/n): "
  read ans
  [ "$ans" = "y" ] || exit 0

  echo -n "是否同时删除已添加的转发规则？(y/n): "
  read del_rules

  echo "正在停止所有 socat 进程..."
  pkill socat 2>/dev/null

  if [ "$del_rules" = "y" ]; then
    echo "删除规则文件及相关配置..."
    rm -rf "$BASE_DIR"
  else
    echo "保留规则文件，删除其他安装文件..."
    rm -f "$MENU_FILE" "$STARTER_FILE" "$CONFIG_FILE"
  fi

  echo "删除软连接..."
  rm -f "$LINK_FILE"

  if [ -f /etc/debian_version ]; then
    systemctl disable socat-forward.service
    systemctl stop socat-forward.service
    rm -f "$SYSTEMD_SERVICE"
    systemctl daemon-reload
  elif [ -f /etc/alpine-release ]; then
    rc-service socat-forward stop
    rc-update del socat-forward default
    rm -f "$OPENRC_SERVICE"
  fi

  green "卸载完成\n"
  exit 0
}

install_main() {
  create_dirs
  install_socat
  if read_install_status; then
    uninstall_prompt
  fi
  download_files
  install_service
  create_link
  write_install_status
  printf "安装完成！请使用 "
  cyan "sfw"
  printf " 命令运行 socat 转发管理脚本。\n"
}

install_main
