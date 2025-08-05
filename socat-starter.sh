#!/bin/sh

BASE_DIR="/usr/local/socat-forward"
RULE_FILE="$BASE_DIR/rules.txt"

pkill socat

# pkill -f "socat TCP4-LISTEN" 2>/dev/null
# pkill -f "socat TCP6-LISTEN" 2>/dev/null
# pkill -f "socat UDP4-LISTEN" 2>/dev/null
# pkill -f "socat UDP6-LISTEN" 2>/dev/null

[ -f "$RULE_FILE" ] || exit 0

success_count=0

is_ipv4() {
  echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

is_ipv6() {
  echo "$1" | grep -Eq ':'
}

create_forward() {
  local proto_type=$1
  local ip_ver=$2
  local lport=$3
  local rip=$4
  local rport=$5

  case "$proto_type" in
    tcp)
      socat_cmd="socat ${ip_ver}-LISTEN:${lport},fork ${ip_ver}:${rip}:${rport}"
      ;;
    udp)
      socat_cmd="socat ${ip_ver}-LISTEN-REUSEADDR:${lport},fork ${ip_ver}-REUSEADDR:${rip}:${rport},nofork"
      ;;
    both)
      nohup socat ${ip_ver}-LISTEN:${lport},fork ${ip_ver}:${rip}:${rport} >/dev/null 2>&1 &
      nohup socat ${ip_ver}-LISTEN-REUSEADDR:${lport},fork ${ip_ver}-REUSEADDR:${rip}:${rport},nofork >/dev/null 2>&1 &
      echo "已创建 ${ip_ver^^} TCP 和 UDP 转发: $lport -> $rip:$rport"
      return 0
      ;;
    *)
      return 1
      ;;
  esac

  nohup $socat_cmd >/dev/null 2>&1 &
  echo "已创建 ${ip_ver^^} $proto_type 转发: $lport -> $rip:$rport"
}

while IFS=' ' read -r LPORT RIP RPORT IP_TYPE PROTO; do
  [ -z "$LPORT" ] && continue

  if is_ipv4 "$RIP"; then
    case "$PROTO" in
      tcp) create_forward tcp TCP4 "$LPORT" "$RIP" "$RPORT" ;;
      udp) create_forward udp UDP4 "$LPORT" "$RIP" "$RPORT" ;;
      both) create_forward both TCP4 "$LPORT" "$RIP" "$RPORT" ;;
      *) echo "未知协议类型: $PROTO" ;;
    esac
  elif is_ipv6 "$RIP"; then
    case "$PROTO" in
      tcp) create_forward tcp TCP6 "$LPORT" "$RIP" "$RPORT" ;;
      udp) create_forward udp UDP6 "$LPORT" "$RIP" "$RPORT" ;;
      both) create_forward both TCP6 "$LPORT" "$RIP" "$RPORT" ;;
      *) echo "未知协议类型: $PROTO" ;;
    esac
  else
    case "$PROTO" in
      tcp) create_forward tcp "TCP${IP_TYPE#ipv}" "$LPORT" "$RIP" "$RPORT" ;;
      udp) create_forward udp "UDP${IP_TYPE#ipv}" "$LPORT" "$RIP" "$RPORT" ;;
      both) create_forward both "TCP${IP_TYPE#ipv}" "$LPORT" "$RIP" "$RPORT" ;;
      *) echo "未知协议类型: $PROTO" ;;
    esac
  fi

  success_count=$((success_count+1))
done < "$RULE_FILE"

if [ "$success_count" -gt 0 ]; then
  echo "\n共创建 $success_count 条转发规则。"
else
  echo "无可用规则，未创建任何转发。"
fi

exit 0
