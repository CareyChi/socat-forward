#!/bin/sh

BASE_DIR="/etc/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"

# 杀掉旧 socat 转发进程
pkill -f "socat TCP4-LISTEN" 2>/dev/null
pkill -f "socat TCP6-LISTEN" 2>/dev/null

[ -f "$RULE_FILE" ] || exit 0

success_count=0

is_ipv4() {
  # 简单判断IPv4格式
  echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

is_ipv6() {
  # 简单判断IPv6格式（包含冒号）
  echo "$1" | grep -Eq ':'
}

while IFS=' ' read -r LPORT RIP RPORT; do
  [ -z "$LPORT" ] && continue

  if is_ipv4 "$RIP"; then
    nohup socat TCP4-LISTEN:"$LPORT",fork TCP4:"$RIP":"$RPORT" >/dev/null 2>&1 &
    echo "已创建 IPv4 转发: $LPORT -> $RIP:$RPORT"
  elif is_ipv6 "$RIP"; then
    nohup socat TCP6-LISTEN:"$LPORT",fork TCP6:"$RIP":"$RPORT" >/dev/null 2>&1 &
    echo "已创建 IPv6 转发: $LPORT -> $RIP:$RPORT"
  else
    # 目标是域名，创建 IPv4 和 IPv6 转发
    nohup socat TCP4-LISTEN:"$LPORT",fork TCP4:"$RIP":"$RPORT" >/dev/null 2>&1 &
    nohup socat TCP6-LISTEN:"$LPORT",fork TCP6:"$RIP":"$RPORT" >/dev/null 2>&1 &
    echo "已创建 IPv4 转发: $LPORT -> $RIP:$RPORT"
    echo "已创建 IPv6 转发: $LPORT -> $RIP:$RPORT"
  fi

  success_count=$((success_count+1))
done < "$RULE_FILE"

if [ "$success_count" -gt 0 ]; then
  echo "\n共创建 $success_count 条转发规则。"
else
  echo "无可用规则，未创建任何转发。"
fi

exit 0
