#!/bin/sh
set -eu

# --- Files
BOOT_DIR="/root/bootstrap"
STATE_FILE="/etc/bootstrap/state"
CONF_FILE="/etc/bootstrap/config"
INITD="/etc/init.d/bootstrap"

mkdir -p "$BOOT_DIR" /etc/bootstrap

cat > "$INITD" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
  procd_open_instance
  procd_set_param command /bin/sh /root/bootstrap/run.sh
  procd_set_param respawn 0
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
}
EOF
chmod +x "$INITD"

cat > "$BOOT_DIR/run.sh" <<'EOF'
#!/bin/sh
set -e

STATE_FILE="/etc/bootstrap/state"
CONF_FILE="/etc/bootstrap/config"
LOG_FILE="/root/bootstrap.log"

GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; NC="\033[0m"
say()  { printf "%b\n" "$*"; }
done() { say "${GREEN}DONE${NC}  $*"; sleep 5; }
warn() { say "${YELLOW}WARN${NC}  $*"; sleep 5; }
fail() { say "${RED}FAIL${NC}  $*"; exit 1; }
log()  { echo "[$(date +'%F %T')] $*" >> "$LOG_FILE"; logger -t bootstrap "$*"; }

get_state() { [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "0"; }
set_state() { echo "$1" > "$STATE_FILE"; sync; }

need_config() { [ ! -f "$CONF_FILE" ]; }

check_openwrt_2410() {
  # Требование podkop: OpenWrt 24.10  [oai_citation:3‡podkop.net](https://podkop.net/docs/install/)
  rel="$(. /etc/openwrt_release; echo "$DISTRIB_RELEASE" 2>/dev/null || true)"
  echo "$rel" | grep -q "^24\.10" || fail "Нужен OpenWrt 24.10.x (сейчас: ${rel:-unknown})."
  done "Версия OpenWrt: $rel"
}

check_inet() {
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || fail "Нет интернета (ping 1.1.1.1)."
  # DNS+TLS (важно для opkg/wget https)
  wget -q --spider https://downloads.openwrt.org/ || fail "Нет DNS/TLS (wget https://downloads.openwrt.org)."
  done "Интернет + HTTPS ок"
}

sync_time() {
  ntpd -q -p 0.openwrt.pool.ntp.org >/dev/null 2>&1 || warn "NTP не сработал (продолжаю)."
  done "Время проверено"
}

check_space() {
  # podkop просит минимум ~20–25MB свободного места  [oai_citation:4‡podkop.net](https://podkop.net/docs/install/)
  free_kb="$(df -k /overlay 2>/dev/null | awk 'NR==2 {print $4}')"
  [ -n "$free_kb" ] || fail "Не вижу /overlay (df)."
  [ "$free_kb" -ge 25600 ] || fail "Мало места в /overlay: ${free_kb}KB. Нужно хотя бы ~25MB."
  done "Свободное место /overlay: $((free_kb/1024)) MB"
}

opkg_update() { opkg update >/dev/null; done "opkg update"; }

install_prereqs() {
  # чтобы wget https и сертификаты работали стабильно
  opkg install ca-bundle ca-certificates wget-ssl >/dev/null 2>&1 || true
  done "Базовые пакеты для https/wget"
}

install_podkop() {
  # Документация предлагает sh <(wget -O - ...), но это bash.
  # На OpenWrt ash делаем так: wget -O - ... | sh  [oai_citation:5‡podkop.net](https://podkop.net/docs/install/)
  wget -qO- "https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh" | sh
  done "Podkop установлен"
}

main() {
  st="$(get_state)"
  log "Boot state=$st"

  if need_config; then
    warn "Нет $CONF_FILE. Создай его (пока можно пустой): echo 'MODE=basic' > $CONF_FILE"
    exit 0
  fi

  [ "$st" -lt 10 ] && check_openwrt_2410 && set_state 10
  [ "$st" -lt 20 ] && install_prereqs      && set_state 20
  [ "$st" -lt 30 ] && check_inet           && set_state 30
  [ "$st" -lt 40 ] && sync_time            && set_state 40
  [ "$st" -lt 50 ] && opkg_update          && set_state 50
  [ "$st" -lt 60 ] && check_space          && set_state 60
  [ "$st" -lt 70 ] && install_podkop       && set_state 70

  done "Bootstrap v0 завершён (дальше добавим меню, VLESS, списки и WireGuard)"
}

main
EOF
chmod +x "$BOOT_DIR/run.sh"

# Создадим минимальный конфиг (потом заменим на меню)
[ -f "$CONF_FILE" ] || echo "MODE=basic" > "$CONF_FILE"

"$INITD" enable
"$INITD" start

echo "OK: bootstrap установлен, сервис включён. Логи: logread -e bootstrap и /root/bootstrap.log"