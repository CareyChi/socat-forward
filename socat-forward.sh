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

# 主脚本远程地址变量
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

# 其他函数保持不变...

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
