#!/bin/sh

BASE_DIR="/etc/local/socat-forward"
CONFIG_FILE="$BASE_DIR/config.json"
RULE_FILE="$BASE_DIR/rules.txt"
STARTER_FILE="$BASE_DIR/socat-starter.sh"
MENU_FILE="$BASE_DIR/socat-forward.sh"
LINK_FILE="/usr/local/bin/sfw"
ALPINE_INIT="/etc/init.d/socat-forward"
CRONTAB_FILE="/etc/crontab"

# 可自行替换以下链接
MENU_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-forward.sh"
STARTER_URL="https://github.com/CareyChi/socat-forward/raw/refs/heads/main/socat-starter.sh"

green() {
  printf '\033[32m%s\033[0m\n' "$1"
}
red() {
  printf '\033[31m%s\033[0m\n' "$1"
}

check_installed() {
  [ -f "$CONFIG_FILE" ] && grep -q '"socatScript1"[[:space:]]*:[[:space:]]*1' "$CONFIG_FILE"
}

prompt_uninstall() {
  echo -n "是否卸载并删除服务？(y/n): "
  read ans
  if [ "$ans" = "y" ]; then
    echo -n "是否同时删除规则文件？(y/n): "
    read delrule
    if [ "$delrule" = "y" ]; then
      rm -rf "$BASE_DIR"
    else
      rm -f "$CONFIG_FILE" "$MENU_FILE" "$STARTER_FILE"
    fi
    [ -f "$LINK_FILE" ] && rm -f "$LINK_FILE"
    if [ -f /etc/debian_version ]; then
      sed -i "\|$STARTER_FILE|d" "$CRONTAB_FILE"
    elif [ -f /etc/alpine-release ]; then
      rc-update del socat-forward default 2>/dev/null
      rm -f "$ALPINE_INIT"
    fi
    green "卸载完成"
    exit 0
  else
    green "操作取消"
    exit 0
  fi
}

install_socat() {
  if ! command -v socat >/dev/null 2>&1; then
    echo "socat 未安装，正在安装..."
    if [ -f /etc/debian_version ]; then
      apt update && apt install -y socat
    elif [ -f /etc/alpine-release ]; then
      apk update && apk add socat
    else
      red "不支持的系统"
      exit 1
    fi
  fi
}

install_script_files() {
  mkdir -p "$BASE_DIR"
  [ ! -f "$RULE_FILE" ] && touch "$RULE_FILE"

  echo "正在下载主脚本..."
  wget -qO "$MENU_FILE" "$MENU_URL" || { red "主脚本下载失败"; exit 1; }
  chmod +x "$MENU_FILE"

  echo "正在下载启动器..."
  wget -qO "$STARTER_FILE" "$STARTER_URL" || { red "启动器下载失败"; exit 1; }
  chmod +x "$STARTER_FILE"

  echo '{"socatScript1": 1}' > "$CONFIG_FILE"

  ln -sf "$MENU_FILE" "$LINK_FILE"
}

setup_autostart() {
  if [ -f /etc/debian_version ]; then
    grep -qF "$STARTER_FILE" "$CRONTAB_FILE" || echo "@reboot root $STARTER_FILE" >> "$CRONTAB_FILE"
  elif [ -f /etc/alpine-release ]; then
    echo "#!/sbin/openrc-run" > "$ALPINE_INIT"
    echo "command=\"$STARTER_FILE\"" >> "$ALPINE_INIT"
    chmod +x "$ALPINE_INIT"
    rc-update add socat-forward default
  fi
}

### 入口
echo "检测安装状态..."
if check_installed; then
  green "已安装"
  prompt_uninstall
else
  red "未安装"
  echo -n "是否继续安装？(y/n): "
  read ans
  [ "$ans" != "y" ] && echo "操作取消" && exit 0
fi

install_socat
install_script_files
setup_autostart

green "安装完成！你可以输入 sfw 来启动主脚本"
