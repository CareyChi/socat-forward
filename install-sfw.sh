#!/bin/sh
BASE_DIR="/usr/local/socat-forward"
CONFIG_FILE="$BASE_DIR/config.json"
MENU_FILE="$BASE_DIR/socat-forward.sh"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
LINK_FILE="/usr/local/bin/sfw"
SYSTEMD_SERVICE="/etc/systemd/system/socat-forward.service"
OPENRC_SERVICE="/etc/init.d/socat-forward"

url_menu="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"
url_starter="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh"
url_service_debian="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/debian/socat-forward-service"
url_service_alpine="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/alpinelinux/socat-forward-service"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
cyan() { printf '\033[36m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

check_command() {
  command -v "$1" >/dev/null 2>&1
}

install_socat() {
  green "[1/5] 检查并安装 socat..."
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
  green "[2/5] 创建安装目录 $BASE_DIR..."
  mkdir -p "$BASE_DIR"
}

download_files() {
  green "[3/5] 下载主脚本和启动器..."
  curl -fsSL "$url_menu?t=$(date +%s)" -o "$MENU_FILE" || exit 1
  curl -fsSL "$url_starter?t=$(date +%s)" -o "$STARTER_FILE" || exit 1
  chmod +x "$MENU_FILE" "$STARTER_FILE"
}

install_service() {
  green "[4/5] 安装系统服务..."
  if [ -f /etc/debian_version ]; then
    curl -fsSL "$url_service_debian?t=$(date +%s)" -o "$SYSTEMD_SERVICE" || exit 1
    chmod 644 "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    systemctl enable socat-forward
    systemctl start socat-forward
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
  green "[5/5] 创建运行快捷命令..."
  ln -sf "$MENU_FILE" "$LINK_FILE"
}

write_install_status() {
  echo '{"installed":1}' > "$CONFIG_FILE"
}

uninstall_prompt() {
  echo -n "检测到已安装，是否卸载？(y/n): "; read ans
  [ "$ans" = "y" ] || exit 0
  echo -n "是否同时删除已添加的转发规则？(y/n): "; read del_all

  pkill -f "socat TCP" 2>/dev/null

  rm -f "$MENU_FILE" "$STARTER_FILE" "$LINK_FILE" "$CONFIG_FILE"
  if [ "$del_all" = "y" ]; then
    if [ -f /etc/debian_version ]; then
      systemctl stop socat-forward
      systemctl disable socat-forward
      rm -f "$SYSTEMD_SERVICE"
      systemctl daemon-reload
    elif [ -f /etc/alpine-release ]; then
      rc-service socat-forward stop
      rc-update del socat-forward default
      rm -f "$OPENRC_SERVICE"
    fi
    rm -rf "$BASE_DIR"
    green "所有文件及规则已删除"
  else
    green "规则文件已保留，其它文件已删除"
  fi
  exit 0
}

read_install_status() {
  [ -f "$CONFIG_FILE" ] && grep -q '"installed":1' "$CONFIG_FILE"
}

install_main() {
  if read_install_status; then
    uninstall_prompt
  fi
  install_socat
  create_dirs
  download_files
  install_service
  create_link
  write_install_status
  green "安装完成"
  echo -n "请使用 " cyan "sfw" " 命令运行 socat 转发管理脚本"
}

install_main
