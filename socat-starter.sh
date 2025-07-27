#!/bin/sh

RULE_FILE="/etc/local/socat-forward/rules.txt"

killall socat 2>/dev/null

if [ ! -f "$RULE_FILE" ]; then
  exit 0
fi

while read -r lport rip rport; do
  if [ -z "$lport" ]; then
    continue
  fi
  nohup socat TCP-LISTEN:"$lport",fork TCP:"$rip":"$rport" >/dev/null 2>&1 &
done < "$RULE_FILE"
