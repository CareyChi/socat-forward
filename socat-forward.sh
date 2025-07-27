#!/bin/sh

BASE_DIR="/etc/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"
CONFIG_FILE="$BASE_DIR/config.json"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
LINK_FILE="/usr/local/bin/sfw"
DEBIAN_CRON="/etc/crontab"
ALPINE_INIT="/etc/init.d/socat-forward"

green() {
  printf '\033[32m%s\033[0m\n' "$1"
}
red() {
  printf '\033[31m%s\033[0m\n' "$1"
}

print_menu() {
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
  echo "0. 卸载服务"
  echo
  echo "按 Ctrl+C 退出脚本"
  echo "==============================="
}

add_rule() {
  echo -n "输入本地监听端口: "
  read lport
  echo -n "输入目标IP或域名: "
  read rip
  echo -n "输入目标端口: "
  read rport

  if [ -z "$lport" ] || [ -z "$rip" ] || [ -z "$rport" ]; then
    red "输入不能为空，操作取消"
    return
  fi

  echo "$lport $rip $rport" >> "$RULE_FILE"
  green "新增规则: $lport -> $rip:$rport"
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
  echo -n "输入要删除的规则编号: "
  read num
  if ! echo "$num" | grep -qE '^[0-9]+$'; then
    red "无效输入"
    return
  fi
  sed -i "${num}d" "$RULE_FILE"
  green "已删除规则 #$num"
}

start_forwarding() {
  if [ ! -f "$STARTER_FILE" ]; then
    red "启动脚本不存在，已中止。"
    return
  fi
  echo "正在启动 socat 转发..."
  "$STARTER_FILE"
}

enable_autostart() {
  if [ -f /etc/debian_version ]; then
    grep -qF "$STARTER_FILE" "$DEBIAN_CRON" || echo "@reboot root $STARTER_FILE" >> "$DEBIAN_CRON"
  elif [ -f /etc/alpine-release ]; then
    echo "#!/sbin/openrc-run" > "$ALPINE_INIT"
    echo "command=\"$STARTER_FILE\"" >> "$ALPINE_INIT"
    chmod +x "$ALPINE_INIT"
    rc-update add socat-forward default
  fi
  green "已启用开机自启"
}

disable_autostart() {
  if [ -f /etc/debian_version ]; then
    sed -i "\|$STARTER_FILE|d" "$DEBIAN_CRON"
  elif [ -f /etc/alpine-release ]; then
    rc-update del socat-forward default >/dev/null 2>&1
    rm -f "$ALPINE_INIT"
  fi
  green "已关闭开机自启"
}

is_autostart_enabled() {
  if [ -f /etc/debian_version ]; then
    grep -qF "$STARTER_FILE" "$DEBIAN_CRON"
  elif [ -f /etc/alpine-release ]; then
    [ -f "$ALPINE_INIT" ]
  else
    return 1
  fi
}

uninstall() {
  echo -n "是否删除规则并清空所有配置？(y/n): "
  read ans
  if [ "$ans" = "y" ]; then
    rm -rf "$BASE_DIR"
  else
    rm -f "$STARTER_FILE" "$CONFIG_FILE"
  fi
  rm -f "$LINK_FILE"
  disable_autostart
  green "卸载完成。"
  exit 0
}

main_loop() {
  while true; do
    print_menu
    echo -n "选择操作: "
    read choice
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
      0) uninstall ;;
      *) red "无效选项" ;;
    esac
    echo
  done
}

main_loop
