# NanoPi R5S/R5C OpenWrt Bootstrap: Podkop + WireGuard + WG Client Manager

🇷🇺 **Русский ** • 🇬🇧 **English below**

---

## 🇷🇺 Русский

### Что это
`bootstrap.sh` — один скрипт для NanoPi R5S/R5C на **чистом OpenWrt**, который по шагам:
- ставит нужные пакеты
- (по желанию) расширяет раздел под `/overlay` (**expand-root** с ребутом)
- устанавливает и настраивает **Podkop** (VLESS + community_lists)
- поднимает **WireGuard** 
- умеет управлять WireGuard-клиентами через меню: список/QR/текстовый конфиг/создать/удалить.

## Архитектура и как это работает (Podkop + WireGuard)
Режим **Podkop + WireGuard** — это “ваш личный VPN до вашего дома”.

### Что вы получаете
1) **Доступ к домашней сети из любой точки мира**  
   Через WireGuard клиент на любом устрйостве вы “попадаете” в вашу LAN-сеть: можно видеть и использовать домашние устройства и сервисы:
   - принтеры, NAS/файловые серверы, камеры, умный дом,
   - домашние компьютеры и локальные веб-интерфейсы,
   - любые ресурсы по локальным IP/именам.

2) **Выход в мировой интернет “как из дома с подкопом”**  
   Трафик вашего устройства идёт через домашний роутер, а дальше — в интернет через вашего провайдера, а часть уходит на ваш VPS через VLESS.  
   Это позволяет:
   - обходить блокировки так же, как если бы вы были дома,
   - не “светить” исходящие соединения с ваших VPS/серверов (нет прямых коннекнов с устройств к VPS, а через одну сессию).

3) **DNS через роутер (DoH внутри Podkop)**  
   В конфигурациях WireGuard клиентов DNS указывается как IP роутера, а роутер уже резолвит через Podkop с DoH. Это делает поведение предсказуемым: DNS тоже проходит “через дом”.

### Важное условие
Чтобы WireGuard-клиенты могли подключаться к вашему дому, нужен **внешний (публичный) IP** на стороне провайдера и нормальная скорость соединения, так как люой клиент будет есть 2х от своей скорости! 

### Требования
- OpenWrt **24.10.x**
- Доступ по SSH (root)
- Интернет на роутере (opkg / загрузка скриптов)

---

### Быстрый старт
1) Подключись по SSH на роутер.
2) Скачай и запусти скрипт:

wget -O /tmp/bootstrap.sh "https://raw.githubusercontent.com/delonet-ai/r5sPodkop/main/bootstrap.sh" && sh /tmp/bootstrap.sh


Режимы меню
	•	0) Basic setup — пакеты + (опционально) expand-root
	•	1) Podkop — установка Podkop и настройка (VLESS + списки)
	•	2) Podkop + WireGuard Private — Podkop + WireGuard + создание клиентов и QR
	•	3) Доустановить WireGuard к Podkop — если Podkop уже есть, добавляет WG и подключает wg0 в Podkop
	•	4) Управление WireGuard клиентами — отдельное меню:
	•	показать список клиентов,
	•	показать QR,
	•	показать текстовый конфиг,
	•	создать клиента,
	•	удалить клиента.

⸻

Как работает “продолжение после ребута”

Скрипт хранит прогресс в:
	•	/etc/r5s-bootstrap.state — текущий шаг (state)
	•	/etc/r5s-bootstrap.conf — выбранные параметры (MODE, VLESS, списки, endpoint)
	•	/root/r5s-bootstrap.log — лог выполнения

Если что-то пошло не так — просто перезапусти скрипт, он продолжит.

⸻

WireGuard: важные моменты
	•	Интерфейс: wg0
	•	Порт: 51820/udp
	•	Сеть (эталон): 10.10.10.0/24, роутер: 10.10.10.1
	•	Firewall: wg0 добавляется в зону lan, входящий UDP/51820 разрешён с wan
	•	Клиентам в конфиге выставляется DNS: 10.10.10.1 (DNS через роутер/Podkop)

Что указывать в Endpoint при создании клиентов
Endpoint — это то, по чему клиент достучится до роутера из интернета:
	•	внешний IP роутера (например 89.207.218.164:51820), или
	•	домен (например wg.example.com:51820)



🇬🇧 English

What is this

bootstrap.sh is a single-file bootstrap script for NanoPi R5S/R5C running a fresh OpenWrt install. It:
	•	installs required packages,
	•	(optionally) expands /overlay (expand-root with reboot),
	•	installs & configures Podkop (VLESS + community_lists),
	•	configures WireGuard using the “golden” layout (wg0 is part of the lan firewall zone),
	•	includes a WireGuard client management menu: list / show QR / show config / create / delete.

⸻
## 🇬🇧 Architecture (Podkop + WireGuard)

The **Podkop + WireGuard** mode is essentially “your personal VPN into your home”.

### What you get
1) **Access to your home network from anywhere**  
   WireGuard connects you into your LAN so you can reach:
   - printers, NAS/file servers, cameras, smart home services,
   - home PCs and local web UIs,
   - anything available on local IPs/hostnames.

2) **Internet access “as if you were at home”**  
   Your device’s traffic goes through your home router and then out via your ISP.  
   This allows you to:
   - bypass blocks the same way you would from home,
   - avoid exposing your outbound traffic as coming from your VPS (traffic exits via home, not via a VPS).

3) **DNS via the router (DoH inside Podkop)**  
   WireGuard client configs point DNS to the router (e.g. `10.10.10.1`), while the router resolves via Podkop using DoH. This keeps DNS behavior consistent and routed “through home”.

### Key requirement
To connect to your home from the Internet you need a **public WAN IP** from your ISP:
- static public IP, or
- dynamic public IP (DDNS is recommended).


Requirements
	•	OpenWrt 24.10.x
	•	SSH access (root)
	•	Internet connectivity (opkg + downloads)
	•	Prefer running interactively (Podkop installer may ask questions)

⸻

Quick start
	1.	SSH into your router.
	2.	Download & run:
wget -O /tmp/bootstrap.sh "https://raw.githubusercontent.com/delonet-ai/r5sPodkop/main/bootstrap.sh" && sh /tmp/bootstrap.sh

  
