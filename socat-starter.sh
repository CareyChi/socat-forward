#!/bin/sh

BASE_DIR="/etc/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"

# 杀死所有旧socat
pkill -f "socat TCP4-LISTEN"

# 读取规则并启动
[ -f "$RULE_FILE" ] || exit 0

while IFS=' ' read -r LPORT RIP RPORT; do
  [ -z "$LPORT" ] && continue
  nohup socat TCP4-LISTEN:"$LPORT",fork TCP4:"$RIP":"$RPORT" &
done
