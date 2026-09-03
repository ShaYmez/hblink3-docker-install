#!/bin/bash
# Publish /etc/hblink3/json/talkgroup_ids.json at /json/talkgroup_ids.json

CONF_SRC="${1:-}"
if [ -z "$CONF_SRC" ]; then
        CONF_SRC="$(cd "$(dirname "$0")" && pwd)/apache-hblink-json.conf"
fi
if [ ! -f "$CONF_SRC" ]; then
        echo "WARNING: $CONF_SRC not found — skipping talkgroup JSON endpoint"
        exit 0
fi

mkdir -p /etc/hblink3/json
chmod 755 /etc/hblink3 /etc/hblink3/json 2>/dev/null || true
if [ -f /etc/hblink3/json/talkgroup_ids.json ]; then
        chmod 644 /etc/hblink3/json/talkgroup_ids.json 2>/dev/null || true
fi

sed -i 's/\r$//' "$CONF_SRC" 2>/dev/null || true
install -m 644 "$CONF_SRC" /etc/apache2/conf-available/hblink-json.conf

a2enmod alias >/dev/null 2>&1 || true
a2enmod headers >/dev/null 2>&1 || true
a2enconf hblink-json >/dev/null 2>&1 || true

if systemctl is-active --quiet apache2; then
        systemctl reload apache2 2>/dev/null || systemctl restart apache2 || true
fi
echo "Talkgroup endpoint: /json/talkgroup_ids.json -> /etc/hblink3/json/talkgroup_ids.json"
