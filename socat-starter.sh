#!/bin/sh

BASE_DIR="/usr/local/socat-forward"
LOG_DIR="$BASE_DIR/logs"
RULE_FILE="$BASE_DIR/rules.txt"
SOCAT_LOG="$LOG_DIR/socat-debug.log"
SOCAT_BIN="/usr/bin/socat"

# 创建日志目录（如果不存在）
mkdir -p "$LOG_DIR"

# 清空日志
echo "====== $(date '+%F %T') ======" > "$SOCAT_LOG"

# 清理旧的 socat 转发进程（只杀监听的）
pkill -f "$SOCAT_BIN .*LISTEN"

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
      socat_cmd="$SOCAT_BIN ${ip_ver}-LISTEN:${lport},fork ${ip_ver}:${rip}:${rport}"
      ;;
    udp)
      socat_cmd="$SOCAT_BIN ${ip_ver}-LISTEN-REUSEADDR:${lport},fork ${ip_ver}-REUSEADDR:${rip}:${rport},nofork"
      ;;
    both)
      echo "执行命令: $SOCAT_BIN ${ip_ver}-LISTEN:${lport},fork ${ip_ver}:${rip}:${rport}" >> "$SOCAT_LOG"
      $SOCAT_BIN ${ip_ver}-LISTEN:${lport},fork ${ip_ver}:${rip}:${rport} >> "$SOCAT_LOG" 2>&1 &
      echo "执行命令: $SOCAT_BIN ${ip_ver}-LISTEN-REUSEADDR:${lport},fork ${ip_ver}-REUSEADDR:${rip}:${rport},nofork" >> "$SOCAT_LOG"
      $SOCAT_BIN ${ip_ver}-LISTEN-REUSEADDR:${lport},fork ${ip_ver}-REUSEADDR:${rip}:${rport},nofork >> "$SOCAT_LOG" 2>&1 &
      echo "已创建 ${ip_ver^^} TCP 和 UDP 转发: $lport -> $rip:$rport" >> "$SOCAT_LOG"
      return 0
      ;;
    *)
      echo "未知协议类型: $proto_type" >> "$SOCAT_LOG"
      return 1
      ;;
  esac

  echo "执行命令: $socat_cmd" >> "$SOCAT_LOG"
  $socat_cmd >> "$SOCAT_LOG" 2>&1 &
  echo "已创建 ${ip_ver^^} $proto_type 转发: $lport -> $rip:$rport" >> "$SOCAT_LOG"
}

while IFS=' ' read -r LPORT RIP RPORT IP_TYPE PROTO; do
  [ -z "$LPORT" ] && continue

  if is_ipv4 "$RIP"; then
    case "$PROTO" in
      tcp) create_forward tcp TCP4 "$LPORT" "$RIP" "$RPORT" ;;
      udp) create_forward udp UDP4 "$LPORT" "$RIP" "$RPORT" ;;
      both) create_forward both TCP4 "$LPORT" "$RIP" "$RPORT" ;;
      *) echo "未知协议类型: $PROTO" >> "$SOCAT_LOG" ;;
    esac
  elif is_ipv6 "$RIP"; then
    case "$PROTO" in
      tcp) create_forward tcp TCP6 "$LPORT" "$RIP" "$RPORT" ;;
      udp) create_forward udp UDP6 "$LPORT" "$RIP" "$RPORT" ;;
      both) create_forward both TCP6 "$LPORT" "$RIP" "$RPORT" ;;
      *) echo "未知协议类型: $PROTO" >> "$SOCAT_LOG" ;;
    esac
  else
    case "$PROTO" in
      tcp) create_forward tcp "TCP${IP_TYPE#ipv}" "$LPORT" "$RIP" "$RPORT" ;;
      udp) create_forward udp "UDP${IP_TYPE#ipv}" "$LPORT" "$RIP" "$RPORT" ;;
      both) create_forward both "TCP${IP_TYPE#ipv}" "$LPORT" "$RIP" "$RPORT" ;;
      *) echo "未知协议类型: $PROTO" >> "$SOCAT_LOG" ;;
    esac
  fi

  success_count=$((success_count + 1))
done < "$RULE_FILE"

if [ "$success_count" -gt 0 ]; then
  echo "\n共创建 $success_count 条转发规则。" >> "$SOCAT_LOG"
  exit 0
else
  echo "无可用规则，未创建任何转发。" >> "$SOCAT_LOG"
  exit 1
fi
