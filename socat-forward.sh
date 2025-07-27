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
    echo "5. 不可用"
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

add_rule() {
  # 彩蛋选择转发类型
  echo "请选择转发类型："
  echo "1) TCP"
  echo "2) UDP"
  echo "3) TCP+UDP"
  echo -n "选择(1-3): "
  read proto_choice
  case "$proto_choice" in
    1) proto="tcp" ;;
    2) proto="udp" ;;
    3) proto="tcpudp" ;;
    *) red "无效选项，默认TCP"; proto="tcp" ;;
  esac

  echo -n "输入本地监听端口: "; read lport
  echo -n "输入目标IP或域名: "; read rip
  echo -n "输入目标端口: "; read rport
  [ -z "$lport" ] || [ -z "$rip" ] || [ -z "$rport" ] && { red "输入不能为空"; return; }

  # 判断是否是IP，还是域名
  if echo "$rip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    iptype="ipv4"
  elif echo "$rip" | grep -q ':'; then
    iptype="ipv6"
  else
    # 域名弹菜单选类型
    echo "目标是域名，请选择要使用的IP类型:"
    echo "1) IPv4"
    echo "2) IPv6"
    echo -n "选择(1-2): "
    read ip_choice
    case "$ip_choice" in
      1) iptype="ipv4" ;;
      2) iptype="ipv6" ;;
      *) red "无效选项，默认IPv4"; iptype="ipv4" ;;
    esac
  fi

  echo "$lport $rip $rport $iptype $proto" >> "$RULE_FILE"
  green "新增规则: $lport -> $rip:$rport ($iptype, $proto)"

  # 添加后自动启动应用规则
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
  fi
}

uninstall() {
  echo -n "是否同时删除已添加的转发规则？(y/n): "; read ans
  if [ "$ans" = "y" ]; then
    disable_autostart
    rm -f "$LINK_FILE"
    rm -rf "$BASE_DIR"
  else
    rm -f "$STARTER_FILE" "$CONFIG_FILE" "$LINK_FILE"
    disable_autostart
  fi

  # 杀掉所有socat进程
  pkill socat 2>/dev/null

  green "卸载完成。"
  exit 0
}

update_script() {
  echo "正在从远程更新主脚本、启动器及服务..."

  # 更新主脚本
  if ! curl -fsSL -H 'Cache-Control: no-cache' "${MENU_URL}?t=$(date +%s)" -o "$MENU_FILE"; then
    red "主脚本更新失败"
    return
  fi
  chmod +x "$MENU_FILE"

  # 更新启动器
  STARTER_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh"
  if ! curl -fsSL -H 'Cache-Control: no-cache' "${STARTER_URL}?t=$(date +%s)" -o "$STARTER_FILE"; then
    red "启动器更新失败"
    return
  fi
  chmod +x "$STARTER_FILE"

  # 更新服务文件
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
      5)
        if ! is_autostart_enabled; then
          start_forwarding
        else
          red "该选项不可用"
        fi
        ;;
      6) ps aux | grep '[s]ocat' ;;
      9) update_script ;;
      0) uninstall ;;
      *) red "无效选项" ;;
    esac
    echo
  done
}

main_loop
