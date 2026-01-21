#!/bin/sh
set -e

STATE="/etc/r5s-bootstrap.state"
CONF="/etc/r5s-bootstrap.conf"
LOG="/root/r5s-bootstrap.log"

GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; NC="\033[0m"

say()  { printf "%b\n" "$*"; }
done_(){ say "${GREEN}DONE${NC}  $*"; sleep 5; }
warn(){ say "${YELLOW}WARN${NC}  $*"; sleep 5; }
fail(){ say "${RED}FAIL${NC}  $*"; exit 1; }

log(){ echo "[$(date +'%F %T')] $*" >> "$LOG"; }

get_state(){ [ -f "$STATE" ] && cat "$STATE" || echo "0"; }
set_state(){ echo "$1" > "$STATE"; sync; }

need_conf(){ [ ! -f "$CONF" ]; }

# ---------- меню (запускается один раз, если конфига нет) ----------
menu() {
  say ""
  say "Выбери конфигурацию:"
  say "0) Basic setup"
  say "1) Podkop"
  say "2) Podkop + WireGuard Private"
  say "3) Доустановить WireGuard Private к Podkop"
  printf "Ввод (0/1/2/3): "
  read -r MODE

  case "$MODE" in
    0|1|2|3) ;;
    *) fail "Неверный выбор" ;;
  esac

  VLESS=""
  LIST_RU=0; LIST_CF=0; LIST_META=0

  if [ "$MODE" = "2" ]; then
    say ""
    say "Вставь строку VLESS (одной строкой):"
    read -r VLESS

    say ""
    say "Выбери списки блокировок (0/1):"
    printf "Russian inside (0/1): "; read -r LIST_RU
    printf "Cloudflare (0/1): ";     read -r LIST_CF
    printf "Meta (0/1): ";           read -r LIST_META
  fi

  cat > "$CONF" <<EOF
MODE=$MODE
VLESS=$VLESS
LIST_RU=$LIST_RU
LIST_CF=$LIST_CF
LIST_META=$LIST_META
EOF
  done_ "Параметры сохранены в $CONF"
}

# ---------- префлайт ----------
check_openwrt() {
  rel="$(. /etc/openwrt_release; echo "$DISTRIB_RELEASE" 2>/dev/null || true)"
  echo "$rel" | grep -q "^24\.10" || fail "Нужен OpenWrt 24.10.x (сейчас: ${rel:-unknown})."
  done_ "OpenWrt версия: $rel"
}

check_space() {
  free_kb="$(df -k /overlay 2>/dev/null | awk 'NR==2 {print $4}')"
  [ -n "$free_kb" ] || fail "Не вижу /overlay"
  [ "$free_kb" -ge 20480 ] || fail "Мало места в /overlay: $((free_kb/1024))MB. Нужно ≥20MB."
  done_ "Свободно /overlay: $((free_kb/1024)) MB"
}

check_inet() {
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || fail "Нет интернета (ping 1.1.1.1)."
  wget -q --spider https://downloads.openwrt.org/ || fail "Нет DNS/TLS (wget https://downloads.openwrt.org)."
  done_ "Интернет + HTTPS OK"
}

sync_time() {
  ntpd -q -p 0.openwrt.pool.ntp.org >/dev/null 2>&1 || warn "NTP не сработал (продолжаю)."
  done_ "Время проверено"
}

opkg_base() {
  opkg update
  opkg install ca-bundle ca-certificates wget-ssl curl nano-full
  done_ "Базовые пакеты установлены"
}

# ---------- Podkop ----------
install_podkop() {
  # На ash используем pipe вместо <( ... )  [oai_citation:4‡podkop.net](https://podkop.net/docs/install/?utm_source=chatgpt.com)
  wget -qO- "https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh" | sh
  done_ "Podkop установлен/обновлён"
}

# Заглушки — добавим после того, как ты дашь “эталонные” конфиги/ключи
configure_podkop() {
  . "$CONF"
  done_ "Настройка Podkop (пока заглушка — сделаем по твоему эталону/uci)"
}

# ---------- WireGuard ----------
install_wireguard() {
  opkg update
  opkg install kmod-wireguard wireguard-tools luci-app-wireguard qrencode
  done_ "WireGuard + QR установлены"
}
configure_wireguard() {
  done_ "Настройка WireGuard (пока заглушка — добавим генерацию peer + QR)"
}

# ---------- main ----------
main() {
  [ -f "$CONF" ] || menu

  st="$(get_state)"
  log "state=$st"

  [ "$st" -lt 10 ] && check_openwrt && set_state 10
  [ "$st" -lt 20 ] && check_space  && set_state 20
  [ "$st" -lt 30 ] && check_inet   && set_state 30
  [ "$st" -lt 40 ] && sync_time    && set_state 40
  [ "$st" -lt 50 ] && opkg_base    && set_state 50

  . "$CONF"
  if [ "$MODE" = "1" ] || [ "$MODE" = "2" ]; then
    [ "$st" -lt 60 ] && install_podkop    && set_state 60
    [ "$st" -lt 70 ] && configure_podkop  && set_state 70
  fi

  if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
    [ "$st" -lt 80 ] && install_wireguard   && set_state 80
    [ "$st" -lt 90 ] && configure_wireguard && set_state 90
  fi

  done_ "Готово. State=$st → $(get_state). Логи: $LOG"
  say "Если был ребут — просто запусти эту же команду ещё раз, продолжит с state=$(get_state)."
}

main
