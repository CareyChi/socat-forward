#!/bin/sh

VERSION="V0.0.2"
BASE_DIR="/usr/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"
CONFIG_FILE="$BASE_DIR/config.json"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
MENU_FILE="$BASE_DIR/socat-forward.sh"
LINK_FILE="/usr/local/bin/sfw"
SYSTEMD_SERVICE="/etc/systemd/system/socat-forward.service"
OPENRC_SERVICE="/etc/init.d/socat-forward"
MENU_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
cyan() { printf '\033[36m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }

fetch_remote_version() {
  curl -fsSL -H 'Cache-Control: no-cache' "${MENU_URL}?t=$(date +%s)" | grep '^VERSION=' | cut -d'"' -f2
}

print_menu() {
  echo ""
  echo "当前版本号: $VERSION"
  remote_ver=$(fetch_remote_version)
  echo "最新版本号: $remote_ver"
  [ "$remote_ver" != "" ] && [ "$remote_ver" != "$VERSION" ] && green "检测到新版本可用！"

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
  echo "6. 查看 socat 当前运行状态"
  echo "9. 更新主脚本"
  echo "0. 卸载服务"
  echo "=================================="
}

is_domain() {
  echo "$1" | grep -vqE '^([0-9]{1,3}\.){3}[0-9]{1,3}$|:'
}

get_ip_type() {
  echo "检测到是域名，请选择转发协议类型："
  echo "1. IPv4"
  echo "2. IPv6"
  echo -n "选择: "
  read opt
  case "$opt" in
    2) echo "ipv6" ;;
    *) echo "ipv4" ;;
  esac
}

add_rule() {
  echo -n "输入本地监听端口: "; read lport
  echo -n "输入目标IP或域名: "; read rip
  echo -n "输入目标端口: "; read rport
  [ -z "$lport" ] || [ -z "$rip" ] || [ -z "$rport" ] && { red "输入不能为空"; return; }

  if is_domain "$rip"; then
    type=$(get_ip_type)
  elif echo "$rip" | grep -q ':'; then
    type="ipv6"
  else
    type="ipv4"
  fi

  echo "$lport $rip $rport $type" >> "$RULE_FILE"
  green "新增规则: $lport -> $rip:$rport ($type)"
  "$STARTER_FILE"
}

list_rules() {
  echo "当前转发规则："
  if [ ! -s "$RULE_FILE" ]; then
    echo "无规则"
  else
    nl "$RULE_FILE"
  fi
}

delete_rule() {
  list_rules
  echo -n "输入要删除的规则编号: "; read num
  echo "$num" | grep -qE '^[0-9]+$' || { red "无效输入"; return; }
  sed -i "${num}d" "$RULE_FILE"
  green "已删除规则 #$num"
  "$STARTER_FILE"
}

start_forwarding() {
  [ -x "$STARTER_FILE" ] && "$STARTER_FILE"
}

enable_autostart() {
  if [ -f /etc/debian_version ]; then
    systemctl enable socat-forward && systemctl start socat-forward
  elif [ -f /etc/alpine-release ]; then
    rc-update add socat-forward && rc-service socat-forward start
  fi
  green "已启用开机自启"
}

disable_autostart() {
  if [ -f /etc/debian_version ]; then
    systemctl disable socat-forward && systemctl stop socat-forward
  elif [ -f /etc/alpine-release ]; then
    rc-update del socat-forward && rc-service socat-forward stop
  fi
  green "已关闭开机自启"
}

is_autostart_enabled() {
  if [ -f /etc/debian_version ]; then
    systemctl is-enabled socat-forward >/dev/null 2>&1
  elif [ -f /etc/alpine-release ]; then
    rc-status | grep -q socat-forward
  fi
}

uninstall() {
  echo -n "是否同时删除已添加的转发规则？(y/n): "; read ans

  pkill -f "socat TCP" 2>/dev/null

  rm -f "$STARTER_FILE" "$CONFIG_FILE" "$LINK_FILE"
  if [ "$ans" = "y" ]; then
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
    green "所有文件及规则已删除。"
  else
    green "规则保留，其余文件删除。"
  fi
  exit 0
}

update_script() {
  curl -fsSL "$MENU_URL?t=$(date +%s)" -o "$MENU_FILE" && chmod +x "$MENU_FILE"
  curl -fsSL "https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh?t=$(date +%s)" -o "$STARTER_FILE" && chmod +x "$STARTER_FILE"
  green "更新完成，重启脚本..."
  exec sh "$MENU_FILE"
}

check_socat_status() {
  echo "当前 socat 转发进程："
  ps aux | grep '[s]ocat'
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
        if is_autostart_enabled; then disable_autostart
        else enable_autostart
        fi
        ;;
      5) if ! is_autostart_enabled; then start_forwarding; else red "该选项仅在未启用开机自启时可用"; fi ;;
      6) check_socat_status ;;
      9) update_script ;;
      0) uninstall ;;
      *) red "无效选项" ;;
    esac
    echo
  done
}

main_loop
