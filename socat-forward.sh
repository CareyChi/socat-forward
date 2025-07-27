#!/bin/sh

VERSION="V0.0.3"

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
red() { printf '\033[31m%s\033[0m\n' "$1"; }
cyan() { printf '\033[36m%s\033[0m\n' "$1"; }

fetch_remote_version() {
  curl -fsSL -H 'Cache-Control: no-cache' "${MENU_URL}?t=$(date +%s)" | head -n 5 | grep '^VERSION=' | head -n1 | cut -d'"' -f2
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
  echo "6. 检查 socat 运行状态"
  echo "9. 更新主脚本"
  echo "0. 卸载服务"
  echo ""
  echo "按 Ctrl+C 退出脚本"
  echo "==============================="
}

is_ipv4() {
  echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

is_ipv6() {
  echo "$1" | grep -Eq ':'
}

add_rule() {
  echo "请选择转发协议类型："
  echo "1. TCP"
  echo "2. UDP"
  echo "3. TCP+UDP"
  read -p "选择(1/2/3): " proto_sel
  case "$proto_sel" in
    1) proto="tcp" ;;
    2) proto="udp" ;;
    3) proto="both" ;;
    *) proto="tcp" ;;
  esac

  echo -n "输入本地监听端口: "; read lport
  echo -n "输入目标IP或域名: "; read rip
  echo -n "输入目标端口: "; read rport

  # 判断是否IP地址
  if is_ipv4 "$rip"; then
    ip_type="ipv4"
  elif is_ipv6 "$rip"; then
    ip_type="ipv6"
  else
    # 域名，需用户选择ipv4/ipv6
    echo "目标是域名，请选择目标地址类型:"
    echo "1. IPv4"
    echo "2. IPv6"
    read -p "选择(1/2): " ipver
    [ "$ipver" = "1" ] && ip_type="ipv4"
    [ "$ipver" = "2" ] && ip_type="ipv6"
  fi

  [ -z "$lport" ] || [ -z "$rip" ] || [ -z "$rport" ] && { red "输入不能为空"; return; }

  echo "$lport $rip $rport $ip_type $proto" >> "$RULE_FILE"
  green "新增规则: $lport -> $rip:$rport ($ip_type/$proto)"

  start_forwarding
}

list_rules() {
  echo "当前转发规则："
  if [ ! -f "$RULE_FILE" ] || [ ! -s "$RULE_FILE" ]; then
    echo "无规则"
    return
  fi
  nl "$RULE_FILE"
}

delete_rule() {
  list_rules
  echo -n "输入要删除的规则编号: "; read num
  echo "$num" | grep -qE '^[0-9]+$' || { red "无效输入"; return; }
  sed -i "${num}d" "$RULE_FILE"
  green "已删除规则 #$num"
  start_forwarding
}

start_forwarding() {
  [ ! -f "$STARTER_FILE" ] && { red "启动脚本不存在"; return; }
  "$STARTER_FILE"
}

enable_autostart() {
  if [ -f /etc/debian_version ]; then
    systemctl enable socat-forward.service
    systemctl start socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    rc-update add socat-forward default
    rc-service socat-forward start
  fi
  green "已启用开机自启"
}

disable_autostart() {
  if [ -f /etc/debian_version ]; then
    systemctl disable socat-forward.service
    systemctl
