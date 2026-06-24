#!/usr/bin/env python3
"""
Aizen Scanner - Cliente (compilado para binario)
Uso: ./aizen_scanner --license AIZEN-XXXXXXXX-XXXXXXXX

Compilar: pip install pyinstaller && pyinstaller --onefile aizen_scanner.py
"""

import subprocess
import json
import sys
import os
import urllib.request
import urllib.error
import time
import hashlib

SERVER_URL = "https://SEU-BOT.replit.app"  # URL do bot

SCANS = {
    "device": r"""
MODEL=$(getprop ro.product.model 2>/dev/null || echo "?")
BRAND=$(getprop ro.product.brand 2>/dev/null || echo "?")
ANDROID=$(getprop ro.build.version.release 2>/dev/null || echo "?")
SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "?")
SERIAL=$(getprop ro.serialno 2>/dev/null || getprop ro.boot.serialno 2>/dev/null || echo "?")
HWID=$(settings get secure android_id 2>/dev/null || echo "?")
UP=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo "0")
MIN=$((UP/60)); HR=$((MIN/60)); MIN=$((MIN%60))
echo "Modelo: $MODEL"
echo "Marca: $BRAND"
echo "Android: $ANDROID (SDK $SDK)"
echo "Serial: $SERIAL"
echo "HWID: $HWID"
echo "Online: ${HR}h ${MIN}m"
BT=$(grep btime /proc/stat 2>/dev/null | awk '{print $2}')
echo "BootTime: $BT"
""",
    "root": r"""
ROOT=0
alert() { echo "[ROOT] $1"; ROOT=1; }
command -v su >/dev/null 2>&1 && alert "su acessivel"
command -v busybox >/dev/null 2>&1 && alert "BusyBox"
getprop ro.debuggable | grep -q "^1$" && alert "ro.debuggable=1"
getprop ro.secure | grep -q "^0$" && alert "ro.secure=0"
getprop | grep -qi magisk && alert "Magisk property"
getprop | grep -qi kernelsu && alert "KernelSU property"
getprop | grep -qi lspd && alert "LSPosed property"
for f in /system/bin/su /system/xbin/su /sbin/su; do [ -e "$f" ] && alert "su em $f"; done
for d in /data/adb /data/magisk; do ls "$d" >/dev/null 2>&1 && alert "pasta $d"; done
SE=$(getenforce 2>/dev/null)
[ "$SE" = "Permissive" ] && alert "SELinux permissive"
[ "$SE" = "Disabled" ] && alert "SELinux disabled"
echo "---"
[ "$ROOT" -eq 1 ] && echo "RESULTADO: ROOT DETECTADO" || echo "RESULTADO: LIMPO"
""",
    "bootloader": r"""
echo "[BOOTLOADER]"
echo "flash.locked=$(getprop ro.boot.flash.locked 2>/dev/null || echo '?')"
echo "vbmeta=$(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo '?')"
echo "verifiedboot=$(getprop ro.boot.verifiedbootstate 2>/dev/null || echo '?')"
echo "warranty=$(getprop ro.boot.warranty_bit 2>/dev/null || echo '?')"
echo "avb=$(getprop ro.boot.avb_version 2>/dev/null || echo '?')"
if getprop ro.boot.flash.locked 2>/dev/null | grep -q "^0$"; then echo "[!] FLASH DESBLOQUEADO"; fi
if getprop ro.boot.vbmeta.device_state 2>/dev/null | grep -qi "unlocked"; then echo "[!] VBMETA UNLOCKED"; fi
if getprop ro.boot.verifiedbootstate 2>/dev/null | grep -qi "orange"; then echo "[!] ORANGE STATE"; fi
""",
    "apps": r"""
UP=$(cut -d. -f1 /proc/uptime)
HZ=$(getconf CLK_TCK 2>/dev/null || echo 100)
echo "[APPS RECENTES]"
for PKG in ru.zdevs.zarchiver bin.mt.plus com.termux com.discord com.android.chrome me.piebridge.brevent com.google.android.apps.docs com.android.vending; do
 PID=$(pidof $PKG 2>/dev/null | awk '{print $1}')
 [ -z "$PID" ] && continue
 START=$(awk '{print $22}' /proc/$PID/stat 2>/dev/null)
 [ -z "$START" ] && continue
 SEC=$((START / HZ)); MIN=$(((UP - SEC) / 60))
 echo " $PKG - ${MIN}min atras"
done
""",
    "replays": r"""
pkg="com.dts.freefiremax"
echo "[REPLAYS]"
BIN=$(ls -t /sdcard/Android/data/$pkg/files/MReplays/*.bin 2>/dev/null | head -1)
JSON=$(ls -t /sdcard/Android/data/$pkg/files/MReplays/*.json 2>/dev/null | head -1)
if [ -n "$BIN" ]; then
 echo "BIN: $(basename $BIN)"
 stat "$BIN" 2>/dev/null | grep -E 'Access|Modify|Change'
 A_BIN=$(stat "$BIN" 2>/dev/null | grep 'Access:' | tail -1 | awk '{print $3}' | cut -d'.' -f2)
 M_BIN=$(stat "$BIN" 2>/dev/null | grep 'Modify:' | tail -1 | awk '{print $2" "$3}' | cut -d'.' -f1)
 C_BIN=$(stat "$BIN" 2>/dev/null | grep 'Change:' | tail -1 | awk '{print $2" "$3}' | cut -d'.' -f1)
 [ "$M_BIN" != "$C_BIN" ] && echo "[!] TIMESTAMP INCONSISTENTE"
 echo "$A_BIN" | grep -qE '^0{9}$|[0-9]999[0-9]' && echo "[!] ACCESS ANOMALO: $A_BIN"
else echo "Sem .bin"; fi
if [ -n "$JSON" ]; then
 echo "JSON: $(basename $JSON)"
 stat "$JSON" 2>/dev/null | grep -E 'Access|Modify|Change'
else echo "Sem .json"; fi
echo ""
echo "[ASSETS]"
stat /storage/emulated/0/Android/data/$pkg/files/contentcache/Optional/android/gameassetbundles 2>/dev/null | grep -E 'Access|Modify|Change' || echo "Pasta nao encontrada"
echo ""
echo "[VERSAO]"
dumpsys package $pkg 2>/dev/null | grep versionName | cut -d= -f2 || echo "?"
""",
    "shizuku": r"""
echo "[SHIZUKU]"
if pm list packages 2>/dev/null | grep -q "moe.shizuku.privileged.api"; then
 echo "Instalado"
 pidof moe.shizuku.privileged.api >/dev/null 2>&1 && echo "Ativo" || echo "Inativo"
 ps -A 2>/dev/null | grep shizuku | grep -q root && echo "Modo root" || echo "Modo ADB"
else echo "Nao instalado"; fi
echo ""
echo "[VPN]"
pm list packages -3 2>/dev/null | grep -iE 'vpn|openvpn|wireguard' | sed 's/package://g' || echo "Nenhuma"
echo ""
echo "[GERENCIADORES]"
pm list packages 2>/dev/null | grep -iE 'mt\.manager|mt\.plus|zarchiver' | sed 's/package://g' || echo "Nenhum"
""",
    "proxy": r"""
echo "[PROXY SCAN]"
for p in com.nu.roxinho com.netflix.mediaclientxx com.proxy.free com.dripclient.proxy com.spotify.musicx; do
 if pm list packages | grep -q "$p"; then echo "INSTALADO: $p"
 else
  HIST=$(dumpsys package 2>/dev/null | grep -A 10 "Removed packages:" | grep -i "$p")
  [ -n "$HIST" ] && echo "REMOVIDO: $p"
 fi
done
""",
    "files": r"""
echo "[ARQUIVOS SUSPEITOS]"
find /storage/emulated/0 -type f 2>/dev/null | grep -iE 'modmenu|wallhack|ffh4x|bypass|headtrack|hack|inject|gg|cheat' | grep -v Download/savagegod | head -20 || echo "Nenhum"
echo ""
echo "[OCULTO]"
for d in /data/local/tmp /sdcard/tmp /sdcard/MIUI/backup/AllBackup; do
 [ -d "$d" ] && echo "$d: $(find $d -type f 2>/dev/null | wc -l) arquivos" && find $d -type f 2>/dev/null | grep -iE '\.so$|\.sh$|\.bin$|cheat|mod|hack' | head -5
done
""",
    "logs": r"""
echo "[LOG INTEGRITY]"
UPTIME=$(cut -d. -f1 /proc/uptime)
FIRST=$(logcat -d 2>/dev/null | head -5 | grep -v "^--" | head -1 | awk '{print $1" "$2}')
if [ -n "$FIRST" ]; then
 TS=$(date -d "$FIRST" +%s 2>/dev/null)
 NOW=$(date +%s)
 [ -n "$TS" ] && DIFF=$(((NOW - TS) / 60)) || DIFF="?"
 if [ "$UPTIME" -gt 1200 ] && [ -n "$DIFF" ] && [ "$DIFF" -lt 5 ]; then echo "ALERTA: Logs limpos! ($DIFF min)"
 else echo "Logs: ${DIFF}min de historico"; fi
fi
echo ""
echo "[ADB/WIRELESS]"
logcat -d 2>/dev/null | grep -iE "AdbDebuggingManager|WirelessDebugging|adbwifi|adbd" | grep -iE "pair|disconnect|tcp|enable" | tail -5 || echo "Nenhuma atividade"
""",
    "time": r"""
echo "[TIME CHECK]"
BT=$(grep btime /proc/stat 2>/dev/null | awk '{print $2}')
NOW=$(date +%s)
UP=$(cut -d. -f1 /proc/uptime)
[ -n "$BT" ] && [ -n "$UP" ] && {
 CALC=$((NOW - BT))
 DIF=$((CALC - UP)); DIF=${DIF#-}
 [ "$DIF" -gt 120 ] && echo "Alteracao manual detectada" || echo "Sistema consistente"
}
echo "Uptime: $((UP/86400))d $(((UP%86400)/3600))h $(((UP%3600)/60))m"
AUTO=$(settings get global auto_time 2>/dev/null)
[ "$AUTO" = "0" ] && echo "Hora automatica: DESATIVADA" || echo "Hora automatica: ATIVA"
echo ""
echo "[DIRETORIOS SENSIVEIS]"
NOW=$(date +%s)
for d in optionalavatarres gameassetbundles; do
 P="/storage/emulated/0/Android/data/com.dts.freefiremax/files/contentcache/Optional/android/$d"
 [ -d "$P" ] && {
  MT=$(stat "$P" 2>/dev/null | grep Modify | head -1 | cut -d' ' -f2-)
  [ -n "$MT" ] && { TS=$(date -d "$MT" +%s 2>/dev/null); [ -n "$TS" ] && [ $(( (NOW - TS) / 60 )) -le 30 ] && echo "  $d: Alterado nos ultimos 30min"; }
 }
done
""",
    "dumpsys": r"""
echo "[APPS RECENTES (dumpsys)]"
dumpsys activity recents 2>/dev/null | grep -E 'Recent #|realActivity' | grep -oE '[a-zA-Z0-9._]+/' | cut -d'/' -f1 | sort -u | head -10 || echo "N/A"
""",
}


def get_hwid():
    try:
        r = subprocess.run(
            ["sh", "-c", "settings get secure android_id 2>/dev/null || getprop ro.serialno 2>/dev/null || echo 'unknown'"],
            capture_output=True, text=True, timeout=5
        )
        hwid = r.stdout.strip()
        return hashlib.sha256(hwid.encode()).hexdigest()[:16]
    except Exception:
        return "unknown"


def run_shell(code):
    try:
        r = subprocess.run(["bash", "-c", code], capture_output=True, text=True, timeout=60)
        return (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        return "[Timeout]"
    except FileNotFoundError:
        return "[bash not found - execute no Termux]"
    except Exception as e:
        return f"[Error: {e}]"


def spinner():
    while True:
        for c in "|/-\\":
            yield c

def collect_all():
    results = {}
    total = len(SCANS)
    i = 0
    sp = spinner()
    for name, code in SCANS.items():
        i += 1
        s = next(sp)
        print(f"\r  {s} Escaneando {name.upper()}...", end="", file=sys.stderr)
        output = run_shell(code)
        results[name] = output
    print(f"\r  \u2713 Coleta concluida! {total} sessoes", " " * 20, file=sys.stderr)
    return results


def send_to_server(server_url, license_key, data, hwid):
    payload = json.dumps({
        "license": license_key,
        "hwid": hwid,
        "data": data,
    }).encode()
    url = f"{server_url.rstrip('/')}/api/collect"
    req = urllib.request.Request(
        url, data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        return {"error": f"HTTP {e.code}: {body}"}
    except urllib.error.URLError as e:
        return {"error": f"Servidor inacessivel: {e.reason}"}
    except Exception as e:
        return {"error": str(e)}


def main():
    if len(sys.argv) < 2 or "--license" not in sys.argv:
        print("Uso: aizen_scanner --license AIZEN-XXXX-XXXX")
        print("     aizen_scanner --server URL --license KEY")
        sys.exit(1)

    server = SERVER_URL
    license_key = ""

    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--server" and i + 1 < len(args):
            server = args[i + 1]
        elif a == "--license" and i + 1 < len(args):
            license_key = args[i + 1]

    if not license_key:
        print("ERRO: Informe --license AIZEN-XXXX-XXXX")
        sys.exit(1)

    if not license_key.startswith("AIZEN-"):
        print("ERRO: Licenca invalida (formato: AIZEN-XXXX-XXXX)")
        sys.exit(1)

    hwid = get_hwid()

    banner = """
##############                    
              ##################                  
            ######          ######                
            ####              ####                
          ######                ####              
          ####                  ####              
          ####                  ####              
            ####              ####                
            ####              ####                
            ######          ######                
              ##################                  
                  ##############                  
                            ######                
                              ######              
                                ####              
                                ######            
                                  ######          
                                    ####
"""
    pad = " " * 10
    for line in banner.strip("\n").split("\n"):
        print(f"{pad}{line}", file=sys.stderr)
    print(file=sys.stderr)
    print(" " * 8 + "AIZEN SCANNER v1.0", file=sys.stderr)
    print(" " * 4 + "Aguarde, coletando informacoes do dispositivo...\n", file=sys.stderr)

    data = collect_all()

    print(f"\n  \U0001f4e1 Enviando dados para analise...", file=sys.stderr)
    result = send_to_server(server, license_key, data, hwid)

    if "error" in result:
        print(f"\n  \u274c ERRO: {result['error']}", file=sys.stderr)
        if "invalida" in result.get("error", "").lower() or "expirada" in result.get("error", "").lower():
            print("  Licenca rejeitada. Contate o analista.", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"\n  \u2705 Scan enviado com sucesso! ID: {result.get('scan_id', '?')}", file=sys.stderr)
        print(f"\n{'='*50}", file=sys.stderr)
        print("   \U0001f4ac AGUARDE O ANALISTA ANALISAR AS LOGS", file=sys.stderr)
        print("   Voce recebera o resultado no seu PV em breve.", file=sys.stderr)
        print(f"{'='*50}\n", file=sys.stderr)


if __name__ == "__main__":
    main()
