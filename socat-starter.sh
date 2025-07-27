#!/bin/sh

BASE_DIR="/etc/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"

pkill -f "socat TCP4-LISTEN" 2>/dev/null
pkill -f "socat TCP6-LISTEN" 2>/dev/null

[ -f "$RULE_FILE" ] || exit 0

success_count=0

while IFS=' ' read -r LPORT RIP RPORT TYPE; do
  [ -z "$LPORT" ] && continue

  if [ "$TYPE" = "ipv4" ]; then
    nohup socat TCP4-LISTEN:"$LPORT",fork TCP4:"$RIP":"$RPORT" >/dev/null 2>&1 &
    echo "已创建 IPv4 转发: $LPORT -> $RIP:$RPORT"
  elif [ "$TYPE" = "ipv6" ]; then
    nohup socat TCP6-LISTEN:"$LPORT",fork TCP6:"$RIP":"$RPORT" >/dev/null 2>&1 &
    echo "已创建 IPv6 转发: $LPORT -> $RIP:$RPORT"
  fi

  success_count=$((success_count+1))
done < "$RULE_FILE"

if [ "$success_count" -gt 0 ]; then
  echo "共创建 $success_count 条转发规则。"
else
  echo "无可用规则，未创建任何转发。"
fi

exit 0
