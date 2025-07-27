#!/bin/sh

RULE_FILE="/etc/local/socat-forward/rules.txt"

killall socat 2>/dev/null

[ -f "$RULE_FILE" ] || exit 0

while read -r lport rip rport; do
  [ -z "$lport" ] && continue
  nohup socat TCP-LISTEN:"$lport",fork TCP:"$rip":"$rport" >/dev/null 2>&1 &
done < "$RULE_FILE"
