#!/usr/bin/env bash
# ==============================================================================
# Консольный парсер VPN-подписок и JSON-конфигов (macOS / Linux Release v1.0)
# Запуск: bash VPN_Parser_Mac_Linux.sh   или   ./VPN_Parser_Mac_Linux.sh
# ==============================================================================

TMP_PY="${TMPDIR:-/tmp}/vpn_parser_engine_$$.py"
cat << 'PY_ENGINE' > "$TMP_PY"
# -*- coding: utf-8 -*-
import base64
import getpass
import hashlib
import json
import os
import platform as py_platform
import re
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

GREEN  = "\033[92m"
RED    = "\033[91m"
CYAN   = "\033[96m"
YELLOW = "\033[93m"
BOLD   = "\033[1m"
GRAY   = "\033[90m"
RESET  = "\033[0m"

HWID_REGEX = re.compile(r"^[a-zA-Z0-9=-]{10,64}$")

PLATFORM_DEFAULTS = {
    "ios":       {"os_name": "iOS",        "os_ver": "18.3", "model": "iPhone 16 Pro Max",        "darwin_ver": "24.3.0", "cfnetwork_ver": "3860.300.31"},
    "android":   {"os_name": "Android",    "os_ver": "15",   "model": "Samsung SM-S928B"},
    "windows":   {"os_name": "Windows",    "os_ver": "11",   "model": "Desktop-PC"},
    "macos":     {"os_name": "macOS",      "os_ver": "15.3", "model": "MacBookPro18,3",           "darwin_ver": "24.3.0", "cfnetwork_ver": "3860.300.31"},
    "linux":     {"os_name": "Linux",      "os_ver": "6.12", "model": "Linux-Workstation"},
    "tvos":      {"os_name": "tvOS",       "os_ver": "18.3", "model": "AppleTV14,1",              "darwin_ver": "24.3.0", "cfnetwork_ver": "3860.300.31"},
    "androidtv": {"os_name": "Android TV", "os_ver": "14",   "model": "NVIDIA SHIELD Android TV"},
}

MESSAGES = {
    "ru": {
        "title":        "ПАРСЕР VPN-ПОДПИСОК",
        "subtitle":     "Выдача: [1] JSON  |  [2] JSON для Sing-box  |  [3] Ключи (URI)",
        "checking_net": "[*] Проверка подключения к интернету...",
        "net_online":   "[OK] Подключение к интернету установлено! Запускаем парсер...",
        "net_offline":  "[X] Нет подключения к интернету! Ссылки подписок могут не загрузиться.",
        "badge_on":     "ИНТЕРНЕТ: ПОДКЛЮЧЕН",
        "badge_off":    "ИНТЕРНЕТ: ОТСУТСТВУЕТ",
        "cur_profile":  "Текущие параметры устройства (отправляются в заголовках запроса):",
        "lbl_plat":     "Платформа (x-device-os)",
        "lbl_model":    "Модель (x-device-model)",
        "lbl_osver":    "Версия ОС (x-ver-os)   ",
        "lbl_hwid":     "HWID (x-hwid)          ",
        "lbl_ua":       "Клиент (User-Agent)    ",
        "menu_hdr":     "Настройка и действия:",
        "m1":           "[1] Выбрать платформу и устройство (iOS, Android, Windows, macOS, Linux, TV)",
        "m2":           "[2] Выбрать клиент User-Agent (Happ, INCY, Sing-box, v2rayTun, Mihomo, Karing)",
        "m3":           "[3] Ввести вручную Платформу / Модель / Версию ОС / User-Agent",
        "m4":           "[4] Изменить или сгенерировать новый HWID",
        "m5":           "[5] Сменить язык / Change language (RU <-> EN)",
        "m_paste":      "• Вставьте ССЫЛКУ на подписку (https://...) или путь к файлу прямо сюда",
        "m_quit":       "• Введите [Q] для выхода",
        "prompt_main":  "Ваш выбор (1-5, ссылка https://... или Q): ",
        "choose_fmt":   "Какой формат вы хотите получить?",
        "f1":           "[1] Обычный JSON (форматированный JSON конфиг)",
        "f2":           "[2] JSON для Sing-box (полный конфиг с selector / urltest)",
        "f3":           "[3] JSON для Sing-box (только секция outbounds)",
        "f4":           "[4] Ключи (vless://, vmess://, trojan://, ss://, hysteria2://)",
        "f5":           "[5] Сразу ВСЕ 3 формата (JSON + Sing-box + Ключи)",
        "prompt_fmt":   "Ваш выбор [4]: ",
        "fetching":     "[*] Запрос подписки:",
        "fetched_ok":   "[+] Ответ успешно получен!",
        "found_nodes":  "[+] Распознано прокси-серверов:",
        "saved_to":     "[+] Файл успешно сохранен:",
        "copied_clip":  "[+] Результат скопирован в буфер обмена!",
        "press_enter":  "\nНажмите Enter, чтобы вернуться в меню...",
        "err_prefix":   "[!] Ошибка:",
    },
    "en": {
        "title":        "VPN SUBSCRIPTION PARSER",
        "subtitle":     "Output: [1] JSON  |  [2] Sing-box JSON  |  [3] Share Keys (URI)",
        "checking_net": "[*] Checking internet connection...",
        "net_online":   "[OK] Internet connection established! Starting parser...",
        "net_offline":  "[X] No internet connection! Subscription links may fail to load.",
        "badge_on":     "INTERNET: ONLINE",
        "badge_off":    "INTERNET: OFFLINE",
        "cur_profile":  "Current Device Parameters (sent in HTTP request headers):",
        "lbl_plat":     "Platform (x-device-os) ",
        "lbl_model":    "Model (x-device-model) ",
        "lbl_osver":    "OS Version (x-ver-os)  ",
        "lbl_hwid":     "HWID (x-hwid)          ",
        "lbl_ua":       "Client (User-Agent)    ",
        "menu_hdr":     "Settings & Actions:",
        "m1":           "[1] Select Platform & Device (iOS, Android, Windows, macOS, Linux, TV)",
        "m2":           "[2] Select Client User-Agent (Happ, INCY, Sing-box, v2rayTun, Mihomo, Karing)",
        "m3":           "[3] Manually enter Platform / Model / OS Version / User-Agent",
        "m4":           "[4] Change or generate a new HWID",
        "m5":           "[5] Change language / Сменить язык (EN <-> RU)",
        "m_paste":      "• Paste your subscription URL (https://...) or local file path right here",
        "m_quit":       "• Enter [Q] to quit",
        "prompt_main":  "Your choice (1-5, https://... link, or Q): ",
        "choose_fmt":   "Which output format do you want to get?",
        "f1":           "[1] Standard JSON (formatted Xray / raw JSON config)",
        "f2":           "[2] Sing-box JSON (complete config with selector / urltest)",
        "f3":           "[3] Sing-box JSON (outbounds array only)",
        "f4":           "[4] Keys (vless://, vmess://, trojan://, ss://, hysteria2://)",
        "f5":           "[5] ALL 3 formats at once (JSON + Sing-box + Keys)",
        "prompt_fmt":   "Your choice [4]: ",
        "fetching":     "[*] Fetching subscription:",
        "fetched_ok":   "[+] Response received successfully!",
        "found_nodes":  "[+] Proxy servers extracted:",
        "saved_to":     "[+] File saved safely to:",
        "copied_clip":  "[+] Result copied to clipboard!",
        "press_enter":  "\nPress Enter to return to the menu...",
        "err_prefix":   "[!] Error:",
    },
}


def get_default_hwid() -> str:
    try:
        seed = f"{py_platform.node()}-{getpass.getuser()}-vpn-parser"
        h = hashlib.sha256(seed.encode("utf-8")).hexdigest().upper()
        return f"{h[0:8]}-{h[8:12]}-4{h[13:16]}-8{h[17:20]}-{h[20:32]}"
    except Exception:
        return str(uuid.uuid4()).upper()


def check_internet() -> tuple[bool, str]:
    endpoints = [
        "http://www.gstatic.com/generate_204",
        "https://1.1.1.1/cdn-cgi/trace",
        "http://connectivitycheck.gstatic.com/generate_204",
    ]
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    for ep in endpoints:
        try:
            req = urllib.request.Request(ep, method="HEAD")
            with urllib.request.urlopen(req, context=ctx, timeout=4) as r:
                if 200 <= r.getcode() < 400:
                    return True, f"({ep})"
        except Exception:
            continue
    return False, ""


def build_user_agent(client: str, platform: str, os_ver: str, model: str) -> str:
    c = client.strip().lower()
    p = platform.strip().lower()
    p_info = PLATFORM_DEFAULTS.get(p, PLATFORM_DEFAULTS["ios"])
    cfnet = p_info.get("cfnetwork_ver", "3860.300.31")
    darwin = p_info.get("darwin_ver", "24.3.0")

    if c == "happ":
        if p in ("ios", "tvos"):
            return f"Happ/4.4.1/ios CFNetwork/{cfnet} Darwin/{darwin}"
        if p == "macos":
            return f"Happ/4.7.2/macos CFNetwork/{cfnet} Darwin/{darwin}"
        if p in ("android", "androidtv"):
            return f"Happ/4.4.1/android Dalvik/2.1.0 (Linux; U; Android {os_ver}; {model})"
        if p == "windows":
            return "Happ/4.7.2/windows"
        if p == "linux":
            return "Happ/4.7.2/linux"
        return "Happ/4.4.1"
    if c == "incy":
        if p in ("ios", "tvos"):
            return f"INCY/2.7.0/ios CFNetwork/{cfnet} Darwin/{darwin}"
        if p == "macos":
            return f"INCY/2.7.0/mac CFNetwork/{cfnet} Darwin/{darwin}"
        if p in ("android", "androidtv"):
            return f"INCY/3.7.0/android Dalvik/2.1.0 (Linux; U; Android {os_ver}; {model})"
        if p == "windows":
            return "INCY/3.4.2/windows"
        return f"INCY/2.7.0/{p}"
    if c == "singbox":
        if p in ("ios", "tvos"):
            return f"SFI/1.11.4 (iOS {os_ver}; sing-box 1.11.4)"
        if p in ("android", "androidtv"):
            return f"SFA/1.11.4 (Android {os_ver}; sing-box 1.11.4)"
        if p == "macos":
            return f"SFM/1.11.4 (macOS {os_ver}; sing-box 1.11.4)"
        return f"sing-box 1.11.4 ({p}; {os_ver})"
    if c == "v2raytun":
        return f"v2rayTun/3.8.15 ({p_info.get('os_name', platform)} {os_ver})"
    if c == "mihomo":
        return f"FlClashX/0.8.72 mihomo/1.19.2 ({p}; {os_ver})"
    if c == "karing":
        return f"Karing/1.2.15.612 ({p} {os_ver}; sing-box)"
    if c == "streisand":
        return f"Streisand/1.6.48 CFNetwork/{cfnet} Darwin/{darwin}"
    if c == "throne":
        return f"Throne/1.0.8 ({p}; {os_ver})"
    return client


def save_output_safe(filename: str, content: str) -> str:
    home = os.path.expanduser("~")
    candidates = [os.getcwd()]
    for sub in ("Downloads", "Desktop", ""):
        d = os.path.join(home, sub) if sub else home
        if os.path.isdir(d) and d not in candidates:
            candidates.append(d)
    candidates.append(tempfile.gettempdir())
    for folder in candidates:
        try:
            full = os.path.join(folder, filename)
            with open(full, "w", encoding="utf-8") as f:
                f.write(content)
            return full
        except Exception:
            continue
    return ""


def copy_clipboard(text: str) -> bool:
    for cmd in (["pbcopy"], ["xclip", "-selection", "clipboard"], ["xsel", "--clipboard", "--input"]):
        try:
            p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
            p.communicate(input=text.encode("utf-8"))
            if p.returncode == 0:
                return True
        except Exception:
            continue
    return False


def decode_b64_safe(data: str) -> str:
    s = data.strip()
    if s.lower().startswith("base64:"):
        s = s[7:].strip()
    if s.startswith("rwEncodeBase64:"):
        s = s[15:].strip()
    s = s.replace("\r", "").replace("\n", "").replace(" ", "")
    if not s:
        return ""
    pad = len(s) % 4
    if pad:
        s += "=" * (4 - pad)
    try:
        return base64.urlsafe_b64decode(s.encode("ascii")).decode("utf-8", errors="replace")
    except Exception:
        return data


def parse_share_uri(line: str):
    s = line.strip()
    if not s or s.startswith("#") or s.startswith("//") or s.startswith("incy://"):
        return None
    if s.startswith("vmess://"):
        try:
            vjson = json.loads(decode_b64_safe(s[8:]))
            if not vjson.get("add") or not vjson.get("port"):
                return None
            return {
                "protocol": "vmess",
                "tag": str(vjson.get("ps") or vjson.get("add")),
                "server": str(vjson["add"]),
                "port": int(vjson["port"]),
                "cred": str(vjson.get("id", "")),
                "flow": "",
                "method": str(vjson.get("scy", "auto")),
                "network": str(vjson.get("net", "tcp")).lower(),
                "security": "tls" if str(vjson.get("tls", "")).lower() == "tls" else "none",
                "sni": str(vjson.get("sni", "")),
                "fp": str(vjson.get("fp", "")),
                "pbk": "",
                "sid": "",
                "spx": "",
                "path": str(vjson.get("path", "")),
                "host": str(vjson.get("host", "")),
                "serviceName": "",
                "xhttpMode": "",
            }
        except Exception:
            return None

    parsed = urllib.parse.urlsplit(s)
    scheme = parsed.scheme.lower()
    if scheme not in ("vless", "trojan", "ss", "shadowsocks", "hysteria2", "hy2"):
        return None
    proto = {"ss": "shadowsocks", "hy2": "hysteria2"}.get(scheme, scheme)
    tag = urllib.parse.unquote(parsed.fragment) if parsed.fragment else f"{proto}-node"
    q = dict(urllib.parse.parse_qsl(parsed.query))
    netloc = parsed.netloc
    userinfo, hostport = ("", netloc)
    if "@" in netloc:
        userinfo, hostport = netloc.rsplit("@", 1)
        userinfo = urllib.parse.unquote(userinfo)
    else:
        dec = decode_b64_safe(netloc)
        if "@" in dec:
            userinfo, hostport = dec.rsplit("@", 1)
    if ":" not in hostport:
        return None
    host_p, port_s = hostport.rsplit(":", 1)
    method = "auto"
    if proto == "shadowsocks":
        if ":" not in userinfo:
            userinfo = decode_b64_safe(userinfo)
        if ":" in userinfo:
            method, userinfo = userinfo.split(":", 1)
    net = q.get("type", "tcp").lower()
    if net in ("raw", "none"):
        net = "tcp"
    sec = q.get("security", "tls" if proto in ("trojan", "hysteria2") else "none").lower()
    return {
        "protocol": proto,
        "tag": tag,
        "server": host_p.strip("[]"),
        "port": int(port_s),
        "cred": userinfo,
        "flow": q.get("flow", ""),
        "method": method,
        "network": net,
        "security": sec,
        "sni": q.get("sni", ""),
        "fp": q.get("fp", ""),
        "pbk": q.get("pbk", ""),
        "sid": q.get("sid", ""),
        "spx": q.get("spx", ""),
        "path": q.get("path", ""),
        "host": q.get("host", ""),
        "serviceName": q.get("serviceName", ""),
        "xhttpMode": q.get("mode", ""),
    }


def extract_nodes(raw_text: str):
    text = raw_text.strip()
    parsed = None
    try:
        parsed = json.loads(text)
    except Exception:
        dec = decode_b64_safe(text)
        if dec and dec != text:
            try:
                parsed = json.loads(dec.strip())
            except Exception:
                text = dec.strip()

    nodes = []
    skip_protos = {"freedom", "blackhole", "dns", "loopback", "direct", "block", "selector", "urltest"}
    skip_tags = {"direct", "block", "dns-out", "dns_out", "direct-out", "block-out"}

    if parsed is not None:
        items = parsed if isinstance(parsed, list) else [parsed]
        for idx, item in enumerate(items, 1):
            if not isinstance(item, dict):
                continue
            remark = str(item.get("remarks") or item.get("name") or "")
            obs = item.get("outbounds") or ([item] if ("protocol" in item or "type" in item) else [])
            for ob in obs:
                if not isinstance(ob, dict):
                    continue
                if "type" in ob and "server" in ob and "server_port" in ob:
                    t = str(ob.get("type", "")).lower()
                    if t in skip_protos:
                        continue
                    tls = ob.get("tls") or {}
                    sec = "reality" if (tls.get("reality") or {}).get("enabled") else ("tls" if tls.get("enabled") else "none")
                    tr = ob.get("transport") or {}
                    nodes.append({
                        "protocol": t,
                        "tag": str(ob.get("tag") or remark or f"{t}-{ob['server']}"),
                        "server": str(ob["server"]),
                        "port": int(ob["server_port"]),
                        "cred": str(ob.get("uuid") or ob.get("password") or ""),
                        "flow": str(ob.get("flow") or ""),
                        "method": str(ob.get("method") or "auto"),
                        "network": str(tr.get("type") or "tcp").lower(),
                        "security": sec,
                        "sni": str(tls.get("server_name") or ""),
                        "fp": str((tls.get("utls") or {}).get("fingerprint") or ""),
                        "pbk": str((tls.get("reality") or {}).get("public_key") or ""),
                        "sid": str((tls.get("reality") or {}).get("short_id") or ""),
                        "spx": "/",
                        "path": str(tr.get("path") or ""),
                        "host": str((tr.get("headers") or {}).get("Host") or tr.get("host") or ""),
                        "serviceName": str(tr.get("service_name") or ""),
                        "xhttpMode": str(tr.get("mode") or ""),
                    })
                    continue

                proto = str(ob.get("protocol", "")).lower()
                ob_tag = str(ob.get("tag", ""))
                if not proto or proto in skip_protos or ob_tag.lower() in skip_tags:
                    continue
                name = remark if (remark and ob_tag in ("", "proxy", "outbound")) else (f"{remark} [{ob_tag}]" if (remark and remark != ob_tag) else (ob_tag or f"Server-{idx}"))
                settings = ob.get("settings") or {}
                srv, port, cred, flow, method = "", 0, "", "", "auto"
                if proto in ("vless", "vmess"):
                    vnext = settings.get("vnext") or []
                    if not vnext:
                        continue
                    srv = str(vnext[0].get("address", ""))
                    port = int(vnext[0].get("port", 0))
                    users = vnext[0].get("users") or []
                    if users:
                        cred = str(users[0].get("id", ""))
                        flow = str(users[0].get("flow", ""))
                        method = str(users[0].get("security", "auto"))
                elif proto in ("trojan", "shadowsocks"):
                    servers = settings.get("servers") or []
                    if not servers:
                        continue
                    srv = str(servers[0].get("address", ""))
                    port = int(servers[0].get("port", 0))
                    cred = str(servers[0].get("password", ""))
                    method = str(servers[0].get("method", "2022-blake3-aes-128-gcm"))
                else:
                    continue
                if not srv or not port:
                    continue
                st = ob.get("streamSettings") or {}
                net = str(st.get("network") or "tcp").lower()
                if net in ("raw", "none"):
                    net = "tcp"
                if net == "splithttp":
                    net = "xhttp"
                sec = str(st.get("security") or "none").lower()
                rset = st.get("realitySettings") or {}
                tset = st.get("tlsSettings") or {}
                wsset = st.get("wsSettings") or {}
                gset = st.get("grpcSettings") or {}
                xh = st.get("xhttpSettings") or st.get("splithttpSettings") or {}
                nodes.append({
                    "protocol": proto,
                    "tag": name,
                    "server": srv,
                    "port": port,
                    "cred": cred,
                    "flow": flow,
                    "method": method,
                    "network": net,
                    "security": sec,
                    "sni": str(rset.get("serverName") or tset.get("serverName") or ""),
                    "fp": str(rset.get("fingerprint") or tset.get("fingerprint") or ""),
                    "pbk": str(rset.get("publicKey") or ""),
                    "sid": str(rset.get("shortId") or ""),
                    "spx": str(rset.get("spiderX") or ""),
                    "path": str(wsset.get("path") or xh.get("path") or ""),
                    "host": str((wsset.get("headers") or {}).get("Host") or xh.get("host") or ""),
                    "serviceName": str(gset.get("serviceName") or ""),
                    "xhttpMode": str(xh.get("mode") or ""),
                })
        return parsed, nodes

    for line in text.splitlines():
        n = parse_share_uri(line)
        if n:
            nodes.append(n)
    return None, nodes


def node_to_uri(n: dict) -> str:
    tag_enc = urllib.parse.quote(n["tag"], safe="")
    if n["protocol"] == "shadowsocks":
        b64 = base64.urlsafe_b64encode(f"{n['method']}:{n['cred']}".encode("utf-8")).decode("ascii").rstrip("=")
        return f"ss://{b64}@{n['server']}:{n['port']}#{tag_enc}"
    if n["protocol"] == "vmess":
        vobj = {
            "v": "2", "ps": n["tag"], "add": n["server"], "port": str(n["port"]), "id": n["cred"],
            "aid": "0", "scy": n["method"] or "auto", "net": n["network"], "type": "none",
            "host": n["host"], "path": n["path"], "tls": "tls" if n["security"] == "tls" else "",
            "sni": n["sni"], "fp": n["fp"]
        }
        b64 = base64.b64encode(json.dumps(vobj, ensure_ascii=False).encode("utf-8")).decode("ascii")
        return f"vmess://{b64}"
    params = {"type": n["network"]}
    if n["security"] and n["security"] != "none":
        params["security"] = n["security"]
    if n["protocol"] == "vless":
        params["encryption"] = "none"
    if n["flow"]:
        params["flow"] = n["flow"]
    if n["sni"]:
        params["sni"] = n["sni"]
    if n["fp"]:
        params["fp"] = n["fp"]
    if n["security"] == "reality":
        if n["pbk"]:
            params["pbk"] = n["pbk"]
        if n["sid"]:
            params["sid"] = n["sid"]
        if n["spx"]:
            params["spx"] = n["spx"]
    if n["network"] in ("ws", "httpupgrade", "http", "xhttp"):
        if n["path"]:
            params["path"] = n["path"]
        if n["host"]:
            params["host"] = n["host"]
        if n["network"] == "xhttp" and n["xhttpMode"]:
            params["mode"] = n["xhttpMode"]
    elif n["network"] == "grpc" and n["serviceName"]:
        params["serviceName"] = n["serviceName"]
    q_str = urllib.parse.urlencode(params, safe="/:,")
    return f"{n['protocol']}://{urllib.parse.quote(n['cred'], safe='')}@{n['server']}:{n['port']}?{q_str}#{tag_enc}"


def node_to_singbox(n: dict) -> dict:
    ob = {"type": n["protocol"], "tag": n["tag"], "server": n["server"], "server_port": n["port"]}
    if n["protocol"] == "vless":
        ob["uuid"] = n["cred"]
        if n["flow"]:
            ob["flow"] = n["flow"]
        ob["packet_encoding"] = "xudp"
    elif n["protocol"] == "vmess":
        ob["uuid"] = n["cred"]
        ob["security"] = n["method"] or "auto"
    elif n["protocol"] in ("trojan", "hysteria2"):
        ob["password"] = n["cred"]
    elif n["protocol"] == "shadowsocks":
        ob["method"] = n["method"] or "2022-blake3-aes-128-gcm"
        ob["password"] = n["cred"]
    if n["security"] in ("tls", "reality"):
        tls = {"enabled": True, "server_name": n["sni"] or n["host"] or n["server"]}
        if n["fp"] or n["security"] == "reality":
            tls["utls"] = {"enabled": True, "fingerprint": n["fp"] or "chrome"}
        if n["security"] == "reality":
            tls["reality"] = {"enabled": True, "public_key": n["pbk"], "short_id": n["sid"]}
        ob["tls"] = tls
    if n["network"] == "ws":
        tr = {"type": "ws", "path": n["path"] or "/"}
        if n["host"]:
            tr["headers"] = {"Host": n["host"]}
        ob["transport"] = tr
    elif n["network"] == "grpc":
        ob["transport"] = {"type": "grpc", "service_name": n["serviceName"]}
    elif n["network"] == "xhttp":
        ob["transport"] = {"type": "xhttp", "path": n["path"] or "/", "host": n["host"], "mode": n["xhttpMode"] or "auto"}
    return ob


def main():
    os.system("clear 2>/dev/null || true")
    print(f"{CYAN}======================================================================{RESET}")
    print(f"{BOLD}                  SELECT LANGUAGE / ВЫБЕРИТЕ ЯЗЫК                     {RESET}")
    print(f"{CYAN}======================================================================{RESET}")
    print(f"  {YELLOW}[1] Русский (Russian){RESET}")
    print(f"  {YELLOW}[2] English (Английский){RESET}")
    print(f"{CYAN}======================================================================{RESET}")
    ans = input("Выберите / Choose [1]: ").strip()
    lang = "en" if ans in ("2", "en", "EN") else "ru"

    print(f"\n{CYAN}{MESSAGES[lang]['checking_net']}{RESET}")
    net_ok, net_detail = check_internet()
    if net_ok:
        print(f"{GREEN}{BOLD}{MESSAGES[lang]['net_online']}{RESET}")
    else:
        print(f"{RED}{BOLD}{MESSAGES[lang]['net_offline']}{RESET}")
    time.sleep(1.2)

    # Дефолтные настройки для релиза: Happ + iPhone 16 Pro Max (iOS 18.3) + уникальный HWID устройства
    state = {
        "platform": "ios",
        "os_name": "iOS",
        "os_ver": "18.3",
        "model": "iPhone 16 Pro Max",
        "client": "happ",
        "hwid": get_default_hwid(),
        "ua": "Happ/4.4.1/ios CFNetwork/3860.300.31 Darwin/24.3.0",
    }

    while True:
        m = MESSAGES[lang]
        os.system("clear 2>/dev/null || true")
        print(f"{CYAN}======================================================================{RESET}")
        print(f"  {BOLD}{m['title']}{RESET}")
        print(f"  {GRAY}{m['subtitle']}{RESET}")
        print(f"{CYAN}======================================================================{RESET}")

        print(f"  {m['cur_profile']}")
        print(f"    {m['lbl_plat']} : {state['os_name']}")
        print(f"    {m['lbl_model']} : {state['model']}")
        print(f"    {m['lbl_osver']} : {state['os_ver']}")
        print(f"    {m['lbl_hwid']} : {YELLOW}{state['hwid']}{RESET}")
        print(f"    {m['lbl_ua']} : {CYAN}{state['ua']}{RESET}")
        print(f"{GRAY}----------------------------------------------------------------------{RESET}")
        print(f"  {BOLD}{m['menu_hdr']}{RESET}")
        print(f"    {m['m1']}")
        print(f"    {m['m2']}")
        print(f"    {m['m3']}")
        print(f"    {m['m4']}")
        print(f"    {m['m5']}")
        print(f"{GRAY}----------------------------------------------------------------------{RESET}")
        print(f"  {GREEN}{m['m_paste']}{RESET}")
        print(f"  {GRAY}{m['m_quit']}{RESET}")
        print(f"{CYAN}======================================================================{RESET}")

        choice = input(f"\n{m['prompt_main']}").strip()
        if not choice:
            continue
        if choice.lower() in ("q", "exit", "выход"):
            break

        if choice == "1":
            print("\n  [1] iOS (iPhone 16 Pro Max, OS 18.3)\n  [2] Android (Samsung SM-S928B, OS 15)\n  [3] Windows (Desktop-PC, OS 11)\n  [4] macOS (MacBookPro18,3, OS 15.3)\n  [5] Linux (Linux-Workstation, OS 6.12)\n  [6] Apple TV (tvOS 18.3)\n  [7] Android TV (NVIDIA SHIELD, OS 14)")
            p_map = {"1": "ios", "2": "android", "3": "windows", "4": "macos", "5": "linux", "6": "tvos", "7": "androidtv"}
            pk = p_map.get(input("  [1-7] [1]: ").strip() or "1", "ios")
            p_def = PLATFORM_DEFAULTS[pk]
            state["platform"] = pk
            state["os_name"] = p_def["os_name"]
            state["os_ver"] = p_def["os_ver"]
            state["model"] = p_def["model"]
            state["ua"] = build_user_agent(state["client"], pk, state["os_ver"], state["model"])
            continue

        if choice == "2":
            print("\n  [1] Happ (Default)\n  [2] INCY\n  [3] Sing-box\n  [4] v2rayTun\n  [5] FlClashX / Mihomo\n  [6] Karing\n  [7] Streisand\n  [8] Throne")
            c_map = {"1": "happ", "2": "incy", "3": "singbox", "4": "v2raytun", "5": "mihomo", "6": "karing", "7": "streisand", "8": "throne"}
            state["client"] = c_map.get(input("  [1-8] [1]: ").strip() or "1", "happ")
            state["ua"] = build_user_agent(state["client"], state["platform"], state["os_ver"], state["model"])
            continue

        if choice == "3":
            v = input(f"  Platform [{state['os_name']}]: ").strip()
            if v:
                state["os_name"] = v
            v = input(f"  Model [{state['model']}]: ").strip()
            if v:
                state["model"] = v
            v = input(f"  OS Version [{state['os_ver']}]: ").strip()
            if v:
                state["os_ver"] = v
            def_ua = build_user_agent(state["client"], state["platform"], state["os_ver"], state["model"])
            v = input(f"  User-Agent [{def_ua}]: ").strip()
            state["ua"] = v if v else def_ua
            continue

        if choice == "4":
            print("\n  [1] Random UUIDv4\n  [2] Default PC-bound UUID\n  [3] 16-char Short ID (Happ format)\n  [4] Custom HWID")
            h = input("  [1-4] [1]: ").strip() or "1"
            if h == "2":
                state["hwid"] = get_default_hwid()
            elif h == "3":
                state["hwid"] = uuid.uuid4().hex[:16].upper()
            elif h == "4":
                ch = input("  HWID: ").strip()
                if ch:
                    state["hwid"] = ch
            else:
                state["hwid"] = str(uuid.uuid4()).upper()
            continue

        if choice == "5":
            lang = "en" if lang == "ru" else "ru"
            continue

        source = choice.strip("\"'")
        print(f"\n{CYAN}{m['choose_fmt']}{RESET}")
        print(f"  {m['f1']}\n  {m['f2']}\n  {m['f3']}\n  {m['f4']}\n  {m['f5']}")
        fmt = input(m["prompt_fmt"]).strip() or "4"

        try:
            if os.path.isfile(source):
                with open(source, "r", encoding="utf-8") as f:
                    raw_body = f.read()
            else:
                print(f"\n{CYAN}{m['fetching']} {source} ...{RESET}")
                req = urllib.request.Request(
                    source,
                    headers={
                        "User-Agent": state["ua"],
                        "x-hwid": state["hwid"],
                        "x-device-os": state["os_name"],
                        "x-ver-os": state["os_ver"],
                        "x-device-model": state["model"],
                        "Accept": "*/*",
                    },
                )
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                with urllib.request.urlopen(req, context=ctx, timeout=25) as r:
                    raw_body = r.read().decode("utf-8", errors="replace")
                print(f"{GREEN}{m['fetched_ok']}{RESET}")

            parsed_json, nodes = extract_nodes(raw_body)
            print(f"{GREEN}{m['found_nodes']} {len(nodes)}{RESET}")

            keys_text = "\n".join(node_to_uri(n) for n in nodes)
            sb_obs = [node_to_singbox(n) for n in nodes]
            sb_tags = [n["tag"] for n in nodes]
            sb_full = {
                "log": {"level": "info", "timestamp": True},
                "inbounds": [
                    {"type": "tun", "tag": "tun-in", "address": ["172.19.0.1/30"], "auto_route": True, "strict_route": True, "stack": "mixed", "sniff": True},
                    {"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080, "sniff": True},
                ],
                "outbounds": [
                    {"type": "selector", "tag": "proxy", "outbounds": ["Auto"] + sb_tags + ["direct"], "default": "Auto" if sb_tags else "direct"},
                    {"type": "urltest", "tag": "Auto", "outbounds": sb_tags, "url": "https://www.gstatic.com/generate_204", "interval": "3m", "tolerance": 50},
                    *sb_obs,
                    {"type": "direct", "tag": "direct"},
                ],
            }
            sb_full_text = json.dumps(sb_full, indent=2, ensure_ascii=False)
            sb_only_text = json.dumps({"outbounds": sb_obs}, indent=2, ensure_ascii=False)
            json_text = json.dumps(parsed_json, indent=2, ensure_ascii=False) if parsed_json is not None else raw_body

            if fmt == "1":
                out_text, out_file = json_text, "output_config.json"
            elif fmt == "2":
                out_text, out_file = sb_full_text, "output_singbox.json"
            elif fmt == "3":
                out_text, out_file = sb_only_text, "output_singbox_outbounds.json"
            elif fmt == "5":
                print(f"\n{GREEN}======================================================================{RESET}")
                print(keys_text)
                print(f"{GREEN}======================================================================{RESET}")
                if copy_clipboard(keys_text):
                    print(f"{GREEN}{m['copied_clip']}{RESET}")
                for fn, txt in (("output_keys.txt", keys_text), ("output_singbox.json", sb_full_text), ("output_config.json", json_text)):
                    p = save_output_safe(fn, txt + "\n")
                    if p:
                        print(f"{YELLOW}{m['saved_to']} {p}{RESET}")
                input(m["press_enter"])
                continue
            else:
                out_text, out_file = keys_text, "output_keys.txt"

            print(f"\n{GREEN}======================================================================{RESET}")
            print(out_text)
            print(f"{GREEN}======================================================================{RESET}")
            if copy_clipboard(out_text):
                print(f"{GREEN}{m['copied_clip']}{RESET}")
            saved = save_output_safe(out_file, out_text + "\n")
            if saved:
                print(f"{YELLOW}{m['saved_to']} {saved}{RESET}")

        except Exception as e:
            print(f"\n{RED}{m['err_prefix']} {e}{RESET}")

        input(m["press_enter"])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n")
PY_ENGINE
python3 "$TMP_PY"
rm -f "$TMP_PY"
