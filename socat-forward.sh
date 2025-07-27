#!/bin/sh

VERSION="V0.0.3"
BASE_DIR="/etc/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"
CONFIG_FILE="$BASE_DIR/config.json"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
MENU_FILE="$BASE_DIR/socat-forward.sh"
LINK_FILE="/usr/local/bin/sfw"
SYSTEMD_SERVICE="/etc/systemd/system/socat-forward.service"
OPENRC_SERVICE="/etc/init.d/socat-forward"

MENU_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

fetch_remote_version() {
  curl -fsSL -H 'Cache-Control: no-cache' "${MENU_URL}?t=$(date +%s)" | grep '^VERSION=' | cut -d'"' -f2
}

print_menu() {
  echo ""
  echo "当前版本号: $VERSION"
  remote_ver=$(fetch_remote_version)
  echo "最新版本号: $remote_ver"
  if [ "$remote_ver" != "" ] && [ "$remote_ver" != "$VERSION" ]; then
    green "检测到新版本可用！"
  fi
  echo "====== socat 端口转发管理器 ======"
  echo "1. 新增转发"
  echo "2. 查看转发"
  echo "3. 删除转发"
  if is_autostart_enabled; then
    echo "4. 关闭开机自启"
  else
    echo "4. 激活开机自启"
    echo "5. 手动启动一次转发"
  fi
  echo "8. 查看socat运行情况"
  echo "9. 更新主脚本"
  echo "0. 卸载服务"
  echo "==============================="
}

is_ipv4() {
  echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

is_ipv6() {
  echo "$1" | grep -Eq ':'
}

add_rule() {
  echo -n "输入本地监听端口: "; read lport
  echo -n "输入目标IP或域名: "; read rip
  echo -n "输入目标端口: "; read rport
  [ -z "$lport" ] || [ -z "$rip" ] || [ -z "$rport" ] && { red "输入不能为空"; return; }

  if is_ipv4 "$rip"; then
    type="ipv4"
  elif is_ipv6 "$rip"; then
    type="ipv6"
  else
    echo "目标是域名，请选择转发类型："
    echo "1. IPv4"
    echo "2. IPv6"
    echo -n "选择(1/2): "; read option
    case "$option" in
      1) type="ipv4" ;;
      2) type="ipv6" ;;
      *) red "无效选择"; return ;;
    esac
  fi

  echo "$lport $rip $rport $type" >> "$RULE_FILE"
  green "新增规则: $lport -> $rip:$rport ($type)"
  start_forwarding
}

list_rules() {
  echo "当前转发规则："
  [ ! -s "$RULE_FILE" ] && echo "无规则" && return
  nl "$RULE_FILE"
}

delete_rule() {
  list_rules
  echo -n "输入要删除的规则编号: "; read num
  echo "$num" | grep -qE '^[0-9]+$' || { red "无效输入"; return; }
  sed -i "${num}d" "$RULE_FILE"
  green "已删除规则 #$num"
}

start_forwarding() {
  [ -f "$STARTER_FILE" ] && "$STARTER_FILE"
}

enable_autostart() {
  if [ -f /etc/debian_version ]; then
    systemctl enable socat-forward.service && systemctl start socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    rc-update add socat-forward default && rc-service socat-forward start
  fi
  green "已启用开机自启"
}

disable_autostart() {
  if [ -f /etc/debian_version ]; then
    systemctl disable socat-forward.service && systemctl stop socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    rc-update del socat-forward default && rc-service socat-forward stop
  fi
  pkill -f socat
  green "已关闭开机自启"
}

is_autostart_enabled() {
  if [ -f /etc/debian_version ]; then
    systemctl is-enabled socat-forward.service >/dev/null 2>&1
  elif [ -f /etc/alpine-release ]; then
    rc-status | grep -q socat-forward
  fi
}

uninstall() {
  echo -n "是否删除规则并清空所有配置？(y/n): "; read ans
  pkill -f socat
  [ "$ans" = "y" ] && rm -rf "$BASE_DIR" || rm -f "$STARTER_FILE" "$CONFIG_FILE"
  rm -f "$LINK_FILE"
  disable_autostart
  green "卸载完成。"
  exit 0
}

update_script() {
  echo "正在更新主脚本和服务..."
  curl -fsSL "${MENU_URL}?t=$(date +%s)" -o "$MENU_FILE" && chmod +x "$MENU_FILE"
  curl -fsSL "https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh?t=$(date +%s)" -o "$STARTER_FILE" && chmod +x "$STARTER_FILE"

  if [ -f /etc/debian_version ]; then
    curl -fsSL "https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/debian/socat-forward-service?t=$(date +%s)" -o "$SYSTEMD_SERVICE" && systemctl daemon-reload && systemctl restart socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    curl -fsSL "https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/alpinelinux/socat-forward-service?t=$(date +%s)" -o "$OPENRC_SERVICE" && rc-service socat-forward restart
  fi

  green "更新完成，重启中..."
  exec sh "$MENU_FILE"
}

main_loop() {
  while true; do
    print_menu
    echo -n "选择操作: "; read choice
    case "$choice" in
      1) add_rule ;;
      2) list_rules ;;
      3) delete_rule ;;
      4)
        if is_autostart_enabled; then disable_autostart; else enable_autostart; fi
        ;;
      5) start_forwarding ;;
      8) ps aux | grep '[s]ocat' ;;
      9) update_script ;;
      0) uninstall ;;
      *) red "无效选项" ;;
    esac
    echo
  done
}

main_loop
