#!/bin/bash
# Static checks for hblink3-docker-install. Safe to run without root.
# Usage: bash tests/check.sh [--live]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAIL=0
PASS=0

ok() { echo "OK    $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL  $1"; FAIL=$((FAIL + 1)); }

SBIN_SCRIPTS="menu flush update upgrade dashboard-upgrade tgmanager-user ssl stop start restart initial-setup uninstall"

echo "=== hblink3-docker-install checks ==="
echo "ROOT=$ROOT"
echo ""

# --- required files ---
for f in \
        hblink3-docker-install.sh \
        docker-compose.yml \
        VERSION \
        CHANGELOG.md \
        README.md \
        files/apache-hblink-json.conf \
        files/apache-hblink-wss.conf \
        files/install-json-endpoint.sh
do
        if [ -f "$f" ]; then
                ok "exists $f"
        else
                bad "missing $f"
        fi
done

for s in $SBIN_SCRIPTS; do
        if [ -f "usr/local/sbin/$s" ]; then
                ok "exists usr/local/sbin/$s"
        else
                bad "missing usr/local/sbin/$s"
        fi
done

# installer copies every sbin script
for s in $SBIN_SCRIPTS; do
        if grep -q "cp -p ${s} /usr/local/sbin/hblink-${s}" hblink3-docker-install.sh \
                || grep -q "cp -p ${s} " hblink3-docker-install.sh; then
                ok "installer installs $s"
        else
                bad "installer does not cp $s"
        fi
done

if grep -q 'hblink-ssl' usr/local/sbin/uninstall; then
        ok "uninstall removes hblink-ssl"
else
        bad "uninstall does not remove hblink-ssl"
fi

# --- no CRLF in shell/yml (Linux / GitHub Actions). Windows checkouts may be CRLF. ---
if [ "${CI:-}" = "true" ] || [ "$(uname -s)" = "Linux" ]; then
        CRLF_HITS=$(grep -l $'\r' hblink3-docker-install.sh docker-compose.yml files/*.sh files/*.conf usr/local/sbin/* tests/*.sh 2>/dev/null || true)
        if [ -z "$CRLF_HITS" ]; then
                ok "no CRLF in scripts/yml/conf"
        else
                bad "CRLF found in: $CRLF_HITS"
        fi
else
        echo "SKIP  CRLF check on $(uname -s)"
fi

# --- bash -n ---
while IFS= read -r -d '' f; do
        if bash -n "$f"; then
                ok "bash -n ${f#"$ROOT"/}"
        else
                bad "bash -n ${f#"$ROOT"/}"
        fi
done < <(find "$ROOT" -type f \( -name '*.sh' -o -path '*/usr/local/sbin/*' \) ! -path '*/.tmp-obp/*' -print0)

# --- VERSION ---
VER=$(head -1 VERSION | tr -d ' \r\n')
if echo "$VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        ok "VERSION is $VER"
else
        bad "VERSION file unexpected: ${VER}"
fi

# --- compose ---
if grep -q 'container_name: hblink' docker-compose.yml && grep -q 'container_name: hbmon' docker-compose.yml; then
        ok "compose has hblink and hbmon"
else
        bad "compose missing hblink/hbmon container names"
fi
if grep -q "image: 'shaymez/hblink3:latest'" docker-compose.yml && grep -q "image: 'shaymez/hbmonv2:latest'" docker-compose.yml; then
        ok "compose uses Hub latest tags"
else
        bad "compose image tags"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        if docker compose -f docker-compose.yml config >/dev/null; then
                ok "docker compose config"
        else
                bad "docker compose config"
        fi
else
        echo "SKIP  docker compose config (docker not available)"
fi

# --- WSS template ---
if grep -q '__FQDN__' files/apache-hblink-wss.conf && grep -q 'Listen 9000' files/apache-hblink-wss.conf; then
        ok "WSS vhost template placeholders"
else
        bad "WSS vhost template"
fi
if grep -q 'Alias /json/talkgroup_ids.json' files/apache-hblink-json.conf; then
        ok "JSON Apache alias"
else
        bad "JSON Apache alias"
fi

# --- dry-run helpers (no root) ---
SSL_OUT=$(bash usr/local/sbin/ssl --help 2>&1) || true
if printf '%s' "$SSL_OUT" | grep -q 'Usage:'; then
        ok "ssl --help"
else
        bad "ssl --help"
fi
SSL_OUT=$(bash usr/local/sbin/ssl --dry-run ci.example.test ci@example.test 2>&1) || true
if printf '%s' "$SSL_OUT" | grep -q 'DRY RUN'; then
        ok "ssl --dry-run"
else
        echo "$SSL_OUT"
        bad "ssl --dry-run"
fi
DU_OUT=$(bash usr/local/sbin/dashboard-upgrade --help 2>&1) || true
if printf '%s' "$DU_OUT" | grep -q 'Usage:'; then
        ok "dashboard-upgrade --help"
else
        bad "dashboard-upgrade --help"
fi
DU_OUT=$(bash usr/local/sbin/dashboard-upgrade --dry-run 2>&1) || true
if printf '%s' "$DU_OUT" | grep -q 'DRY RUN'; then
        ok "dashboard-upgrade --dry-run"
else
        echo "$DU_OUT"
        bad "dashboard-upgrade --dry-run"
fi
UN_OUT=$(bash usr/local/sbin/uninstall --dry-run 2>&1) || true
if printf '%s' "$UN_OUT" | grep -q 'DRY RUN'; then
        ok "uninstall --dry-run"
else
        echo "$UN_OUT"
        bad "uninstall --dry-run"
fi

# --- live (installed host) ---
if [ "${1:-}" = "--live" ]; then
        echo ""
        echo "=== live host checks ==="
        if [ -f /etc/hblink3/docker-compose.yml ]; then
                if command -v docker >/dev/null 2>&1; then
                        if docker compose -f /etc/hblink3/docker-compose.yml config >/dev/null; then
                                ok "live compose config"
                        else
                                bad "live compose config"
                        fi
                fi
        else
                bad "/etc/hblink3/docker-compose.yml missing"
        fi
        if command -v apache2ctl >/dev/null 2>&1; then
                if apache2ctl configtest >/dev/null 2>&1; then
                        ok "apache2ctl configtest"
                else
                        apache2ctl configtest || true
                        bad "apache2ctl configtest"
                fi
        else
                echo "SKIP  apache2ctl"
        fi
        for s in /usr/local/sbin/hblink-*; do
                [ -f "$s" ] || continue
                if bash -n "$s"; then
                        ok "bash -n $(basename "$s")"
                else
                        bad "bash -n $(basename "$s")"
                fi
        done
        if command -v certbot >/dev/null 2>&1; then
                if certbot renew --dry-run; then
                        ok "certbot renew --dry-run"
                else
                        bad "certbot renew --dry-run"
                fi
        else
                echo "SKIP  certbot"
        fi
        if command -v docker >/dev/null 2>&1; then
                if docker ps --format '{{.Names}}' | grep -qx hblink && docker ps --format '{{.Names}}' | grep -qx hbmon; then
                        ok "hblink and hbmon containers running"
                else
                        bad "hblink/hbmon not both running"
                fi
        fi
fi

echo ""
echo "Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -ne 0 ]; then
        exit 1
fi
exit 0
