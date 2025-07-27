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
red() { printf '\033[31m%s\033[0m\n' "$1"; }

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
  fi

  echo "5. 手动启动一次转发"
  echo "6. 查看 socat 进程状态"
  echo "9. 更新主脚本"
  echo "0. 卸载服务"
  echo ""
  echo "按 Ctrl+C 退出脚本"
  echo "==============================="
}

add_rule() {
  # (添加规则部分不变，添加完调用启动器)
  echo -n "请选择转发协议类型："
  echo "1. TCP"
  echo "2. UDP"
  echo "3. TCP+UDP"
  echo -n "选择(1/2/3): "
  read proto_choice
  case "$proto_choice" in
    1) proto="tcp" ;;
    2) proto="udp" ;;
    3) proto="both" ;;
    *) red "无效选项"; return ;;
  esac

  echo -n "输入本地监听端口: "; read lport
  echo -n "输入目标IP或域名: "; read rip
  echo -n "输入目标端口: "; read rport
  [ -z "$lport" ] || [ -z "$rip" ] || [ -z "$rport" ] && { red "输入不能为空"; return; }

  # 判断IP还是域名，域名则询问IP版本
  if echo "$rip" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    ip_type="ipv4"
  elif echo "$rip" | grep -q ':'; then
    ip_type="ipv6"
  else
    echo "目标是域名，请选择目标地址类型:"
    echo "1. IPv4"
    echo "2. IPv6"
    echo -n "选择(1/2): "
    read ip_choice
    case "$ip_choice" in
      1) ip_type="ipv4" ;;
      2) ip_type="ipv6" ;;
      *) red "无效选项"; return ;;
    esac
  fi

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
    systemctl stop socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    rc-update del socat-forward default
    rc-service socat-forward stop
  fi
  green "已关闭开机自启"
}

is_autostart_enabled() {
  if [ -f /etc/debian_version ]; then
    systemctl is-enabled socat-forward.service >/dev/null 2>&1
  elif [ -f /etc/alpine-release ]; then
    rc-status | grep -q socat-forward
  else
    return 1
  fi
}

check_socat_process() {
  ps aux | grep '[s]ocat'
}

uninstall() {
  echo -n "是否同时删除已添加的转发规则？(y/n): "; read ans
  if [ "$ans" = "y" ]; then
    rm -rf "$BASE_DIR"
  else
    rm -f "$STARTER_FILE" "$CONFIG_FILE"
  fi
  rm -f "$LINK_FILE"
  disable_autostart
  pkill -f "socat"
  green "卸载完成。"
  exit 0
}

update_script() {
  echo "正在从远程更新主脚本、启动器及服务..."

  if ! curl -fsSL -H 'Cache-Control: no-cache' "${MENU_URL}?t=$(date +%s)" -o "$MENU_FILE"; then
    red "主脚本更新失败"
    return
  fi
  chmod +x "$MENU_FILE"

  STARTER_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh"
  if ! curl -fsSL -H 'Cache-Control: no-cache' "${STARTER_URL}?t=$(date +%s)" -o "$STARTER_FILE"; then
    red "启动器更新失败"
    return
  fi
  chmod +x "$STARTER_FILE"

  if [ -f /etc/debian_version ]; then
    SERVICE_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/debian/socat-forward-service"
    if ! curl -fsSL -H 'Cache-Control: no-cache' "${SERVICE_URL}?t=$(date +%s)" -o "$SYSTEMD_SERVICE"; then
      red "Debian服务文件更新失败"
      return
    fi
    chmod 644 "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    systemctl restart socat-forward.service
  elif [ -f /etc/alpine-release ]; then
    SERVICE_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/init/alpinelinux/socat-forward-service"
    if ! curl -fsSL -H 'Cache-Control: no-cache' "${SERVICE_URL}?t=$(date +%s)" -o "$OPENRC_SERVICE"; then
      red "Alpine服务文件更新失败"
      return
    fi
    chmod +x "$OPENRC_SERVICE"
    rc-service socat-forward restart
  fi

  green "更新完成，重启脚本..."
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
        if is_autostart_enabled; then
          disable_autostart
        else
          enable_autostart
        fi
        ;;
      5) start_forwarding ;;
      6) check_socat_process ;;
      9) update_script ;;
      0) uninstall ;;
      *) red "无效选项" ;;
    esac
    echo
  done
}

main_loop
