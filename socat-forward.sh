#!/bin/sh
VERSION="V0.0.1"

BASE_DIR="/etc/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"
CONFIG_FILE="$BASE_DIR/config.json"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
MENU_FILE="$BASE_DIR/socat-forward.sh"
LINK_FILE="/usr/local/bin/sfw"
DEBIAN_CRON="/etc/crontab"
ALPINE_INIT="/etc/init.d/socat-forward"

# 远程主脚本URL
MENU_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"

green() {
  printf '\033[32m%s\033[0m\n' "$1"
}
red() {
  printf '\033[31m%s\033[0m\n' "$1"
}

fetch_remote_version() {
  remote_ver=$(wget -qO- "$MENU_URL" | head -n1 | grep -o 'VERSION="[^"]*"' | cut -d'"' -f2)
  echo "$remote_ver"
}

print_menu() {
  echo "当前版本号: $VERSION"
  remote_ver=$(fetch_remote_version)
  echo "最新版本号: $remote_ver"
  if [ "$remote_ver" != "" ] && [ "$remote_ver" != "$VERSION" ]; then
    printf '\033[32m%s\033[0m\n' "有新版本可用！请选择9更新"
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
  echo "9. 更新主脚本"
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

update_script() {
  echo "正在从远程更新主脚本..."
  if wget -qO "$MENU_FILE" "$MENU_URL"; then
    chmod +x "$MENU_FILE"
    green "更新完成，正在重启脚本..."
    exec sh "$MENU_FILE"
  else
    red "更新失败，请检查网络"
  fi
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
      9) update_script ;;
      0) uninstall ;;
      *) red "无效选项" ;;
    esac
    echo
  done
}

main_loop
