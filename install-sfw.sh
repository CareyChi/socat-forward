#!/bin/sh

# ====== 设置下载地址 ======
url_menu="https://your-domain.com/socat-forward.sh"
url_starter="https://your-domain.com/socat-starter.sh"

# ====== 路径定义 ======
BASE_DIR="/etc/local/socat-forward"
CONFIG_FILE="$BASE_DIR/config.json"
RULE_FILE="$BASE_DIR/rules.txt"
MENU_FILE="$BASE_DIR/socat-forward.sh"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
LINK_FILE="/usr/local/bin/sfw"

# ====== 彩色输出函数 ======
green() { echo "\033[32m$1\033[0m"; }
red() { echo "\033[31m$1\033[0m"; }

# ====== 安装 socat ======
check_socat() {
  if command -v socat >/dev/null 2>&1; then
    return
  fi
  echo "未检测到 socat，正在安装..."
  if [ -f /etc/alpine-release ]; then
    apk update && apk add socat
  elif [ -f /etc/debian_version ]; then
    apt update && apt install -y socat
  else
    red "不支持的系统"
    exit 1
  fi
}

# ====== 检查是否已安装 ======
check_installed() {
  if [ -f "$CONFIG_FILE" ] && grep -q '"socatScript1": *1' "$CONFIG_FILE"; then
    green "已安装"
    echo -n "是否卸载？(y/n): "
    read ans
    if [ "$ans" = "y" ]; then
      uninstall
    fi
    exit 0
  else
    red "未安装"
    echo -n "是否继续安装？(y/n): "
    read ans
    [ "$ans" != "y" ] && exit 0
  fi
}

# ====== 创建目录 ======
setup_dirs() {
  [ -d "$BASE_DIR" ] || mkdir -p "$BASE_DIR"
}

# ====== 下载主脚本和启动器 ======
download_scripts() {
  wget -qO "$MENU_FILE" "$url_menu" || { red "主脚本下载失败"; exit 1; }
  wget -qO "$STARTER_FILE" "$url_starter" || { red "启动器下载失败"; exit 1; }
  chmod +x "$MENU_FILE" "$STARTER_FILE"
  [ -f "$RULE_FILE" ] || touch "$RULE_FILE"
}

# ====== 写入 config.json ======
write_config() {
  echo '{ "socatScript1": 1 }' > "$CONFIG_FILE"
}

# ====== 设置开机自启 ======
setup_autostart() {
  if [ -f /etc/debian_version ]; then
    grep -qF "$STARTER_FILE" /etc/crontab || echo "@reboot root $STARTER_FILE" >> /etc/crontab
  elif [ -f /etc/alpine-release ]; then
    echo "#!/sbin/openrc-run" > /etc/init.d/socat-forward
    echo "command=\"$STARTER_FILE\"" >> /etc/init.d/socat-forward
    chmod +x /etc/init.d/socat-forward
    rc-update add socat-forward default
  fi
}

# ====== 创建软链接 ======
create_symlink() {
  ln -sf "$MENU_FILE" "$LINK_FILE"
}

# ====== 卸载逻辑 ======
uninstall() {
  echo -n "是否删除规则文件？(y/n): "
  read del
  if [ "$del" = "y" ]; then
    rm -rf "$BASE_DIR"
  else
    rm -f "$MENU_FILE" "$STARTER_FILE" "$CONFIG_FILE"
  fi
  rm -f "$LINK_FILE"

  if [ -f /etc/debian_version ]; then
    sed -i "\|$STARTER_FILE|d" /etc/crontab
  elif [ -f /etc/alpine-release ]; then
    rc-update del socat-forward default 2>/dev/null
    rm -f /etc/init.d/socat-forward
  fi
  red "已卸载"
  exit 0
}

main() {
  check_socat
  check_installed
  setup_dirs
  download_scripts
  write_config
  setup_autostart
  create_symlink
  green "安装完成，使用 'sfw' 命令启动管理器"
}

main
