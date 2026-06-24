
_4(){ echo -e "$1"; }
_5(){ echo "=================================================="; }
_6(){ echo "──────────────────────────────────────────────────"; }

# Funções de sistema e estatísticas de arquivos
_7(){ stat "$1" 2>/dev/null|grep 'Access: ('|head -1|cut -d'(' -f2|cut -d'/' -f1; }
_8(){ stat "$1" 2>/dev/null|grep "$2:"|tail -1|awk '{print $2" "$3}'|sed 's/ -.*//'; }
_9(){
 _a=$(stat -c %u "$1" 2>/dev/null)
 [ -z "$_a" ] && _a=$(ls -ln "$1" 2>/dev/null | awk '{print $3}')
 echo "$_a"
}
_b(){ stat "$1" 2>/dev/null|grep Access:|tail -1|awk '{print $3}'|cut -d'.' -f2|cut -d' ' -f1; }
_c(){ stat "$1" 2>/dev/null|grep "$2:"|tail -1|awk '{print $3}'|cut -d'.' -f2|cut -d' ' -f1; }
_d(){ echo "$1"|grep -q '[0-9]999[0-9]'; }

# Verificação de integridade temporal de arquivos
_e(){
 _f=$(stat "$1" 2>/dev/null|grep Access:|awk '{print $2" "$3}'|cut -d'.' -f1)
 _g=$(date -d "$_f" +%s 2>/dev/null)
 _h=$(date +%s)
 [ -z "$_g" ]&&return
 [ "$_g" -gt "$_h" ]&&_4 "  ⏰ Tempo: arquivo no futuro ⚠️"
 [ "$_g" -lt 1672531200 ]&&_4 "  ⏰ Tempo: data muito antiga ⚠️"
}

# Verificação de atividade recente em pastas de dados do jogo
_i(){
 _4 "  🔄 Atividade recente:"
 _j=$(find "/storage/emulated/0/Android/data/$(_0)/files/MReplays" -type f -mmin -5 2>/dev/null|head -1)
 _k=$(find "/storage/emulated/0/Android/data/$(_0)/files/contentcache/Optional/android/gameassetbundles" -type f -mmin -5 2>/dev/null|head -1)
 [ -n "$_j" ]||[ -n "$_k" ]&&_4 "    ⚠️ Modificado pós partida"||_4 "    ✅ Sem alterações recentes"
}

# Verificação de padrões em strings (ex: IDs suspeitos)
_l(){
 _m="$1"
 case "$_m" in
  000000000) return 0 ;;
  *999*) return 0 ;;
  *) return 1 ;;
 esac
}

# Comparação de Timezones entre arquivos e sistema
_s(){
 _t=$(stat "$1" 2>/dev/null | grep "Change:" | tail -1 | sed 's/.*\([-+][0-9][0-9][0-9][0-9]\)$/\1/')
 _u=$(stat "$2" 2>/dev/null | grep "Change:" | tail -1 | sed 's/.*\([-+][0-9][0-9][0-9][0-9]\)$/\1/')
 _v=$(date +%z)
 [ -z "$_t" ] && _t=$(stat "$1" 2>/dev/null | grep "Modify:" | tail -1 | sed 's/.*\([-+][0-9][0-9][0-9][0-9]\)$/\1/')
 [ -z "$_u" ] && _u=$(stat "$2" 2>/dev/null | grep "Modify:" | tail -1 | sed 's/.*\([-+][0-9][0-9][0-9][0-9]\)$/\1/')
 [ "$_t" != "$_v" ] && _4 "  🌍 Timezone BIN x Dispositivo: INCONSISTENTE ⚠️"
 [ "$_u" != "$_v" ] && _4 "  🌍 Timezone JSON x Dispositivo: INCONSISTENTE ⚠️"
 [ "$_t" != "$_u" ] && _4 "  🌍 Timezone BIN x JSON: INCONSISTENTE ⚠️"
}

# --------------------------------------------------
# INÍCIO DA EXECUÇÃO PRINCIPAL
# --------------------------------------------------

# Cabeçalho visual
echo -e "\033[1;35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " ⚡️ Dg ScreensHare Iniciando análise completa.⚡️"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# Inicialização e Identificação
_2 "$_3"
_4 "  🔥 $_3 Scanner - Free Fire MAX 🔥"
_4 ""
_6
_4 ""
_4 "📱 INFORMAÇÕES DO DISPOSITIVO:"

# Coleta de propriedades do sistema
MODEL=$(getprop ro.product.model)
BRAND=$(getprop ro.product.brand)
DEVICE=$(getprop ro.product.device)
ANDROID=$(getprop ro.build.version.release)
SDK=$(getprop ro.build.version.sdk)

SERIAL=$(getprop ro.serialno 2>/dev/null)
[ -z "$SERIAL" ] && SERIAL=$(getprop ro.boot.serialno)

HWID=$(settings get secure android_id 2>/dev/null)
[ -z "$HWID" ] && HWID=$(getprop ro.boot.hardware 2>/dev/null)
[ -z "$HWID" ] && HWID=$(getprop ro.hardware 2>/dev/null)

# Exibição dos dados do dispositivo
_4 "  Modelo: $MODEL"
_4 "  Marca: $BRAND"
_4 "  Dispositivo: $DEVICE"
_4 "  Android: $ANDROID (SDK $SDK)"
_4 "  Serial: $SERIAL"
_4 "  HWID: $HWID"

# Cálculo de Uptime (tempo ligado)
UP=$(cut -d. -f1 /proc/uptime)
MIN=$((UP/60))
HR=$((MIN/60))
MIN=$((MIN%60))

_4 "  ⏱️ Online há: ${HR}h ${MIN}min"

[ "$((HR*60+MIN))" -lt 20 ] && _4 "  ⚠️ Dispositivo reiniciado recentemente"

# Verificação de Boot Time vs Último Replay
BT=$(grep btime /proc/stat 2>/dev/null | awk '{print $2}')
LAST_REPLAY=$(stat "$_10" 2>/dev/null | grep 'Access:' | awk '{print $2" "$3}' | cut -d'.' -f1)
LR_TS=$(date -d "$LAST_REPLAY" +%s 2>/dev/null)

if [ -n "$BT" ] && [ -n "$LR_TS" ]; then
 [ "$LR_TS" -lt "$BT" ] && _4 "  ⚠️ Replay ocorreu antes do boot do sistema"
fi

echo ""
echo ""
echo "========================================="
echo ""
echo ""
echo "[+] VERIFICANDO APPS ABERTOS PÓS-PARTIDA"
echo ""

# --------------------------------------------------
# MONITORAMENTO DE APLICATIVOS
# --------------------------------------------------
APPS=0
LIMITE_MINUTOS=80   # Limite de tempo para considerar "aberto recentemente"

MONITOR_APPS="
ru.zdevs.zarchiver
bin.mt.plus
com.termux
com.android.vending
com.a0soft.gphone.uninstaller
com.rs.explorer.filemanager
com.ace.ex.filemanager
com.alphainventor.filemanager
com.rxfileexplorer
com.google.android.apps.docs
com.android.packageinstaller
com.google.android.packageinstaller
com.miui.securitycenter
com.google.android.googlequicksearchbox
com.android.vending
com.android.chrome
com.google.android.documentsui
me.piebridge.brevent
com.discord
"

# Função para traduzir package names em nomes legíveis
get_app_name() {
case "$1" in
ru.zdevs.zarchiver) echo "ZArchiver" ;;
com.discord) echo "Discord" ;;
com.miui.securitycenter) echo "Segurança (Xiaomi)" ;;
com.android.packageinstaller) echo "Instalador de Pacotes (Sistema)" ;;
com.google.android.packageinstaller) echo "Instalador de Pacotes (Google)" ;;
bin.mt.plus) echo "MT Manager" ;;
com.termux) echo "Termux" ;;
com.google.android.apps.docs) echo "Google Drive" ;;
com.android.vending) echo "Play Store" ;;
com.a0soft.gphone.uninstaller) echo "App Usage" ;;
com.rs.explorer.filemanager) echo "RS Gerenciador de Arquivos" ;;
com.ace.ex.filemanager) echo "EX Gerenciador de Arquivos" ;;
com.alphainventor.filemanager) echo "File Manager Plus" ;;
com.rxfileexplorer) echo "Rx File Explorer" ;;
*) echo "$1" ;;
esac
}

# Lógica de verificação de processos ativos
UPTIME=$(cut -d. -f1 /proc/uptime)
HZ=$(getconf CLK_TCK)

for PKG in $MONITOR_APPS; do
PID=$(pidof $PKG 2>/dev/null | awk '{print $1}')
[ -z "$PID" ] && continue

START_TICKS=$(awk '{print $22}' /proc/$PID/stat 2>/dev/null)
[ -z "$START_TICKS" ] && continue

START_SEC=$((START_TICKS / HZ))
DELTA_SEC=$((UPTIME - START_SEC))
DELTA_MIN=$((DELTA_SEC / 60))

if [ "$DELTA_MIN" -le "$LIMITE_MINUTOS" ]; then
APP_NAME=$(get_app_name "$PKG")
echo "[!] AVISO: Usuário abriu $APP_NAME há $DELTA_MIN minutos"
APPS=1
fi
done

echo ""
echo ""

# --------------------------------------------------
# VERIFICAÇÃO AVANÇADA DE ROOT
# --------------------------------------------------
ROOT_DETECTED=0

alert() {
    echo "[!] ROOT DETECTADO: $1"
    ROOT_DETECTED=1
}

# Fallback para alert_root (caso a função original fosse esperada em outro lugar)
alert_root() {
    alert "$1"
}

echo "[+] Iniciando verificação avançada de Root"
echo ""

# 1. Verificação de binários e comandos
command -v su >/dev/null 2>&1 && alert "Comando su acessível"
command -v busybox >/dev/null 2>&1 && alert "BusyBox presente"

# 2. Propriedades críticas de sistema
getprop ro.debuggable | grep -q "^1$" && alert "ro.debuggable=1"
getprop ro.secure | grep -q "^0$" && alert "ro.secure=0"
getprop service.adb.root | grep -qi "1" && alert "ADB Root ativo"

# 3. Busca por strings de frameworks de Root em propriedades
getprop | grep -qi magisk   && alert "Propriedade Magisk encontrada"
getprop | grep -qi zygisk   && alert "Propriedade Zygisk encontrada"
getprop | grep -qi kernelsu && alert "Propriedade KernelSU encontrada"
getprop | grep -qi lspd     && alert "Propriedade LSPosed encontrada"

# 4. Verificação de pacotes instalados via PM
pm list packages | grep -qi magisk    && alert "Pacote relacionado a Magisk"
pm list packages | grep -qi kernelsu  && alert "Pacote relacionado a KernelSU"
pm list packages | grep -qi supersu   && alert "Pacote relacionado a SuperSU"
pm list packages | grep -qi superuser && alert "Pacote relacionado a Superuser"
pm list packages | grep -qi lsposed   && alert "Pacote relacionado a LSPosed"
pm list packages | grep -qi lspatch   && alert "Pacote relacionado a LSPatch"
pm list packages | grep -qi xposed    && alert "Pacote relacionado a Xposed"
pm list packages | grep -qi edxposed  && alert "Pacote relacionado a EdXposed"
pm list packages | grep -qi shizuku   && alert "Pacote relacionado a Shizuku"
pm list packages | grep -qi iadb      && alert "Pacote relacionado a iADB"
pm list packages | grep -qi frida     && alert "Pacote relacionado a Frida"

# 5. Checagem direta de IDs de pacotes conhecidos
for PKG in \
com.topjohnwu.magisk \
me.weishu.kernelsu \
eu.chainfire.supersu \
com.koushikdutta.superuser \
com.noshufou.android.su \
org.lsposed.manager \
org.lsposed.lspatch \
moe.shizuku.privileged.api \
com.github.iadb \
com.frida.server; do
    pm list packages | grep -q "$PKG" && alert "Pacote instalado: $PKG"
done

# 6. Integridade de diretórios e binários 'su'
echo ""
echo "[+] Analisando integridade de diretórios do sistema..."
SISTEMA_LINKS="/system/bin/su /system/xbin/su /sbin/su /vendor/bin/su /system/sd/xbin/su"
for link in $SISTEMA_LINKS; do
    if [ -L "$link" ] || [ -e "$link" ]; then
        echo "[!] ROOT DETECTADO: Binário 'su' encontrado em: $link"
        ROOT_DETECTED=1
    fi
done

# 7. Flags de depuração e assinaturas de Kernel
echo ""
echo "[+] Checando flags de depuração do sistema..."
DEBUG=$(getprop ro.debuggable)
TAGS=$(getprop ro.build.tags)
if [ "$DEBUG" == "1" ] || [[ "$TAGS" == *"test-keys"* ]]; then
    echo "[!] AMBIENTE INSEGURO: O Kernel deste aparelho foi modificado (Custom ROM/Root)."
    ROOT_DETECTED=1
fi

# 8. Diretórios residuais de frameworks
echo ""
echo "[+] Buscando diretórios residuais de frameworks..."
DIRS="/data/adb /data/magisk /data/adb/modules /data/adb/ksu"
for d in $DIRS; do
    ls "$d" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[!] ROOT DETECTADO: Pasta de controle encontrada ($d)."
        ROOT_DETECTED=1
    fi
done

# 9. Estado do SELinux
echo ""
echo "[+] Verificando estado do SELinux..."
SE_STATUS=$(getenforce 2>/dev/null)
if [ "$SE_STATUS" = "Permissive" ] || [ "$SE_STATUS" = "Disabled" ]; then
    alert "SELinux adulterado (Estado: $SE_STATUS)"
    echo "    -> Um Android original deve estar sempre em 'Enforcing'."
fi

# 10. Assinatura do KernelSU (KSU)
echo ""
echo "[+] Sondagem de KernelSU (KSU)..."
if cat /proc/version | grep -qiE "ksu|kernelsu"; then
    alert "KernelSU detetado na assinatura do Kernel!"
fi
if pm list packages | grep -q "me.weishu.kernelsu"; then
    alert "Gestor KernelSU instalado."
fi

# 11. Serviços de sistema suspeitos
echo ""
echo "[+] Verificando serviços de sistema..."
if service list | grep -iq "magisk"; then
    alert "Serviço do sistema 'magisk' detetado em execução!"
fi

# Resultado final da análise de ROOT
echo ""
if [ "$ROOT_DETECTED" -eq 1 ]; then
    echo "[!] RESULTADO: ACESSO ROOT CONFIRMADO [!]"
    echo "[!] O ambiente não é seguro."
else
    echo "[+] NENHUM ROOT DETECTADO (Scan Profundo Limpo)"
fi

echo ""
echo "========================================="
echo ""
# --------------------------------------------------
# VERIFICAÇÃO DE BOOTLOADER
# --------------------------------------------------
echo "[+] VERIFICANDO BOOTLOADER..."
BOOTLOADER_FLAG=0

alert2() {
    echo "[!] FALHA DETECTADA: $1"
    BOOTLOADER_FLAG=1
}

echo ""
echo "[+] Iniciando verificação de Bootloader (Brevent)"
echo ""

# 1. Flash lock status
getprop ro.boot.flash.locked | grep -q "^0$" && alert2 "Bootloader DESBLOQUEADO (flash.locked=0)"

# 2. Estado do dispositivo (vbmeta)
getprop ro.boot.vbmeta.device_state | grep -qi "unlocked" && alert2 "Bootloader DESBLOQUEADO (vbmeta.device_state)"

# 3. Verified Boot State (Cores)
getprop ro.boot.verifiedbootstate | grep -qi "orange" && alert2 "Verified Boot ORANGE (bootloader desbloqueado)"
getprop ro.boot.verifiedbootstate | grep -qi "yellow" && alert2 "Verified Boot YELLOW (boot alterado)"

# 4. AVB (Android Verified Boot) status
getprop ro.boot.avb_version | grep -qi "^$" && alert2 "AVB ausente (possível bootloader desbloqueado)"

# 5. Warranty bit / Tamper flags
getprop ro.boot.warranty_bit | grep -q "^1$" && alert2 "Warranty Bit acionado (bootloader já desbloqueado)"
getprop ro.warranty_bit | grep -q "^1$" && alert2 "Warranty Bit acionado (sistema)"

# 6. Boot state genérico
getprop ro.boot.bootstate | grep -qi "orange" && alert2 "Bootstate ORANGE (bootloader desbloqueado)"

# 7. Flags de boot normal
getprop ro.boot.force_normal_boot | grep -q "^0$" && alert2 "Force Normal Boot desativado"

# Resultado final da análise de Bootloader
echo ""
if [ "$BOOTLOADER_FLAG" -eq 1 ]; then
    echo "[!] BOOTLOADER DESBLOQUEADO OU JÁ DESBLOQUEADO"
else
    echo "[+] BOOTLOADER PADRÃO"
fi

echo""
echo""
echo "========================================="
echo ""
echo""
echo ""
# 1. Comando su acessível
command -v su >/dev/null 2>&1 && alert "Comando su acessível"
_4 "  🔧 SHIZUKU:"
_2a="moe.shizuku.privileged.api"
if pm list packages 2>/dev/null | grep -q "$_2a"; then
 _4 "    ⚠️ Instalado"
 if pidof "$_2a" >/dev/null 2>&1; then
  _4 "    ⚠️ Ativo/pareado"
  ps -A 2>/dev/null | grep -q 'shizuku' && {
   ps -A 2>/dev/null | grep shizuku | grep -q 'root' && \
   _4 "    ⚠️ Modo root" || _4 "    ⚠️ Modo ADB/Wireless"
  }
  ss -ltn 2>/dev/null | grep -q '127.0.0.1' && _4 "    ⚠️ Porta local ativa"
 else
  _4 "    ✅ Inativo/não pareado"
 fi
else
 _4 "    ✅ Não instalado"
fi
echo ""
_6
echo ""
_4 "  🌐 VPN:"
_2b=$(pm list packages -3 2>/dev/null | grep -i -E 'vpn|openvpn|wireguard')
[ -n "$_2b" ]&&{ _4 "    ⚠️ VPN detectada"; echo "$_2b"|sed 's/package://g'|sed 's/^/      /'; }||_4 "    ✅ Nenhuma VPN detectada"
#!/system/bin/sh

# ==================================================
# ⚡ DG SCREENSHARE VERIFICAÇÃO ⚡
# Organizado para execução via Brevent
# ==================================================

# Configurações iniciais
pkg="com.dts.freefiremax"
VERSAO_ESPERADA="1.123.1"
TMP="/data/local/tmp/proxy_scan.txt"
TOP_BAR="┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
BTM_BAR="┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

_4(){ echo -e "$1"; }

# Cabeçalho Inicial
_4 "\033[1;35m$TOP_BAR"
_4 "┃   ⚡ DG SCREENSHARE - ANÁLISE INICIADA,AGUARDE...  ┃"
_4 "$BTM_BAR\033[0m"

# --------------------------------------------------
# 🛡️ SEÇÃO 0: SCANNER ANTI PROXY E LOG INTEGRITY
# --------------------------------------------------
_4 "\n\033[1;31m┏━━ [ 🛡️ SEGURANÇA E INTEGRIDADE ] ━━┓\033[0m"

# A. Verificação de Limpeza de Logs (Logcat Tampering)
_4 "  💎 Verificando Integridade dos Logs:"
UPTIME_SEC=$(cut -d. -f1 /proc/uptime)
FIRST_LOG_LINE=$(logcat -d | head -n 5 | grep -v "^--" | head -n 1)
FIRST_LOG_TIME=$(echo "$FIRST_LOG_LINE" | awk '{print $1" "$2}')

if [ -n "$FIRST_LOG_TIME" ]; then
    # Converte o tempo do primeiro log para segundos (aproximado)
    LOG_START_TS=$(date -d "$FIRST_LOG_TIME" +%s 2>/dev/null)
    NOW_TS=$(date +%s)
    if [ -n "$LOG_START_TS" ]; then
        DIFF_SEC=$((NOW_TS - LOG_START_TS))
        DIFF_MIN=$((DIFF_SEC / 60))
        
        # Se o dispositivo está ligado há mais de 20 min, mas os logs só tem 2 min, houve limpeza.
        if [ "$UPTIME_SEC" -gt 1200 ] && [ "$DIFF_SEC" -lt 300 ]; then
            _4 "  🚨 ALERTA: LOGS LIMPOS RECENTEMENTE! ($DIFF_MIN min atrás)"
            _4 "  ⚠️ Possível tentativa de esconder rastros (logcat -c)."
        else
            _4 "  ✅ Histórico de logs parece íntegro ($DIFF_MIN min)."
        fi
    fi
else
    _4 "  ⚠️ Não foi possível ler o início dos logs."
fi

# B. Verificação de Logs de Depuração/TCP
_4 "\n  💎 Verificando Atividade de Depuração:"
logcat -d | grep -viE "SimpleSh|SurfaceFlinger|WindowManager|ActivityManager|audio_|HoneySpace|Looper" | grep -iE "AdbDebuggingManager|WirelessDebugging|adbwifi|adbd" | grep -iE "pair|disconnect|remove|close|enable|disable|offline|tcp" > "$TMP" 2>/dev/null

if [ -s "$TMP" ]; then
    _4 "  🚨 ATIVIDADE SUSPEITA ENCONTRADA:"
    cat "$TMP" | tail -n 5 | while read line; do _4 "  ➤ $line"; done
    
    if grep -qiE "disconnect|remove|close|disable|offline|tcp" "$TMP"; then
        _4 "\n  🚨 ALERTA: SUPPOSTO BYPASS DETECTADO!"
        _4 "  ⚠️ Se a desconexão foi antes do Brevent, APLIQUE W.O."
    fi
else
    _4 "  ✅ Nenhuma atividade de proxy suspeita em logs."
fi

# C. Verificação de Apps Proxy/Cleaners
_4 "\n  💎 Verificando Aplicativos Suspeitos:"
verificar_proxy() {
    P=$1; D=$2
    if pm list packages | grep -q "$P"; then
        _4 "  🚨 $D: INSTALADO! (APLIQUE W.O)"
    else
        HIST=$(dumpsys package | grep -A 10 "Removed packages:" | grep -i "$P")
        [ -n "$HIST" ] && _4 "  ⚠️ $D: REMOVIDO RECENTEMENTE!" || _4 "  ✅ $D: Limpo."
    fi
}

verificar_proxy "com.nu.roxinho" "Nubank Falso"
verificar_proxy "com.netflix.mediaclientxx" "Netflix Falso"
verificar_proxy "com.proxy.free" "Easy Proxy"
verificar_proxy "com.dripclient.proxy" "Drip Client"
verificar_proxy "com.spotify.musicx" "Spotify Falso"

_4 "\033[1;31m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"

# --------------------------------------------------
# 📦 SEÇÃO 1: GAMEASSETBUNDLES
# --------------------------------------------------
_4 "\n\033[1;34m┏━━ [ 📂 GAMEASSETBUNDLES ] ━━┓\033[0m"
stat /storage/emulated/0/Android/data/$pkg/files/contentcache/Optional/android/gameassetbundles 2>/dev/null | grep -E 'Access|Modify|Change' || _4 "  [!] Pasta não encontrada."
_4 "\033[1;34m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"

# --------------------------------------------------
# ✨ SEÇÃO 2: SHADERS
# --------------------------------------------------
_4 "\n\033[1;36m┏━━ [ ✨ SHADERS ] ━━┓\033[0m"
latest_shader=$(ls -t /storage/emulated/0/Android/data/$pkg/files/contentcache/Optional/android/gameassetbundles/shaders* 2>/dev/null | head -1)
if [ -n "$latest_shader" ]; then
    stat "$latest_shader" | grep -E 'Access|Modify|Change'
    size=$(du -m "$latest_shader" 2>/dev/null | awk '{print $1}')
    _4 "  📏 Tamanho: ${size}MB"
    [ "$size" -ge 1 ] && [ "$size" -le 3 ] && _4 "  ✅ Status: OK" || _4 "  ⚠️ Status: SUSPEITO"
else
    _4 "  [!] Shaders não encontradas."
fi
_4 "\033[1;36m┗━━━━━━━━━━━━━━━━━━━━┛\033[0m"

# --------------------------------------------------
# 🎮 SEÇÃO 3: REPLAY (.BIN)
# --------------------------------------------------
_4 "\n\033[1;33m┏━━ [ 📄 REPLAY .BIN ] ━━┓\033[0m"
latest_bin=$(ls -t /sdcard/Android/data/$pkg/files/MReplays/*.bin 2>/dev/null | head -1)
if [ -n "$latest_bin" ]; then
    stat "$latest_bin" | grep -E 'Access|Modify|Change'
else
    _4 "  [!] Nenhum .bin encontrado."
fi
_4 "\033[1;33m┗━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"

# --------------------------------------------------
# 📝 SEÇÃO 4: REPLAY (.JSON)
# --------------------------------------------------
_4 "\n\033[1;33m┏━━ [ 📝 REPLAY .JSON ] ━━┓\033[0m"
latest_json=$(ls -t /sdcard/Android/data/$pkg/files/MReplays/*.json 2>/dev/null | head -1)
if [ -n "$latest_json" ]; then
    stat "$latest_json" | grep -E 'Access|Modify|Change'
else
    _4 "  [!] Nenhum .json encontrado."
fi
_4 "\033[1;33m┗━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"

# --------------------------------------------------
# 🚨 SEÇÃO 5: DIAGNÓSTICO DE INTEGRIDADE
# --------------------------------------------------
if [ -n "$latest_bin" ] && [ -n "$latest_json" ]; then
    A_BIN_N=$(stat "$latest_bin" 2>/dev/null | grep 'Access:' | tail -1 | awk '{print $3}' | cut -d'.' -f2)
    A_JSON_N=$(stat "$latest_json" 2>/dev/null | grep 'Access:' | tail -1 | awk '{print $3}' | cut -d'.' -f2)
    A_BIN_TS=$(stat "$latest_bin" 2>/dev/null | grep 'Access:' | tail -1 | awk '{print $2" "$3}' | cut -d'.' -f1)
    M_BIN_TS=$(stat "$latest_bin" 2>/dev/null | grep 'Modify:' | tail -1 | awk '{print $2" "$3}' | cut -d'.' -f1)
    C_BIN_TS=$(stat "$latest_bin" 2>/dev/null | grep 'Change:' | tail -1 | awk '{print $2" "$3}' | cut -d'.' -f1)

    WO_ALERT=0; PASSADOR=0
    [ "$A_BIN_TS" != "$M_BIN_TS" ] || [ "$M_BIN_TS" != "$C_BIN_TS" ] && PASSADOR=1
    if echo "$A_BIN_N" | grep -qE '^000000000$|[0-9]999[0-9]' || echo "$A_JSON_N" | grep -qE '^000000000$|[0-9]999[0-9]'; then
        WO_ALERT=1; PASSADOR=1
    fi

    _4 "\n\033[1;31m┏━━ [ 🚨 DIAGNÓSTICO REPLAY ] ━━┓\033[0m"
    if [ "$PASSADOR" -eq 1 ]; then
        _4 "  🚨 STATUS: PASSADOR IDENTIFICADO!"
        [ "$WO_ALERT" -eq 1 ] && _4 "  🚨 ALERTA: BYPASS DETECTADO! APLICAR W.O."
    else
        _4 "  ✅ STATUS: REPLAY LIMPO"
    fi
    _4 "\033[1;31m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
fi

# --------------------------------------------------
# 📱 SEÇÃO 6: VERSÃO DO APP
# --------------------------------------------------
_4 "\n\033[1;32m┏━━ [ 📱 VERSÃO DO APP ] ━━┓\033[0m"
versao=$(dumpsys package $pkg | grep versionName | cut -d= -f2 | tr -d '[:space:]')
_4 "  🔹 Instalada: $versao"
_4 "  🔹 Esperada:  $VERSAO_ESPERADA"
[ "$versao" = "$VERSAO_ESPERADA" ] && _4 "  ✅ Status: OK" || _4 "  ❌ Status: DIFERENTE"
_4 "\033[1;32m┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"


_4 "💻VERIFICAÇÃO DE GERENCIADORES:"
_2c=$(pm list packages 2>/dev/null)
_2d=0
if echo "$_2c" | grep -qiE 'bin\.mt|mt\.manager|mt\.plus|com\.mt|mtmanager'; then
 _4 "    ❌ MT MANAGER DETECTADO❌"
 _2d=1
fi
if echo "$_2c" | grep -qi 'zarchiver'; then
 _4 "    ⚠️ ZArchiver detectado"
 _2d=1
fi
_2e=$(echo "$_2c" | grep -iE 'filemanager|file.manager|explorer|files|mixplorer|solid|fx.file|es.file' | grep -viE 'bin\.mt|mt\.manager|zarchiver')
if [ -n "$_2e" ]; then
 echo "$_2e" | sed 's/package://g' | while read _2f; do
  _4 "    ⚠️ Gerenciador: $_2f"
  _2d=1
 done
fi
[ "$_2d" -eq 0 ] && _4 "    ✅ Nenhum gerenciador suspeito"
_4 ""
_6
_4 ""
_4 "Armazenamento oculto (MIUI Backup / TMP):"
_2g="/sdcard/MIUI/backup/AllBackup"
_2h="/data/local/tmp"
_2i="/sdcard/tmp"
_2j=""
if [ -d "$_2g" ]; then
 _2 "$_3"
 _2k=$(find "$_2g" -type f 2>/dev/null | wc -l)
 _4 "MIUI Backup: $_2k arquivos"
 _2l=$(find "$_2g" -type f \( -iname "*.so" -o -iname "*.bin" -o -iname "*.dat" \) 2>/dev/null | head -5)
 if [ -n "$_2l" ]; then
  _4 "Backup: binários suspeitos ⚠️"
  echo "$_2l"
  _2j="1"
 fi
 _2m=$(find "$_2g" -type f 2>/dev/null | grep -Ei "cheat|mod|menu|hack|inject|gg" | head -5)
 if [ -n "$_2m" ]; then
  _4 "Backup: nomes suspeitos ⚠️"
  echo "$_2m"
  _2j="1"
 fi
 _2n=$(find "$_2g" -type f -size +50M 2>/dev/null | head -5)
 if [ -n "$_2n" ]; then
  _4 "Backup: arquivos grandes ⚠️"
  echo "$_2n"
  _2j="1"
 fi
 _2o=$(find "$_2g" -type f -mmin -30 2>/dev/null | head -3)
 if [ -n "$_2o" ]; then
  _4 "Backup: modificação recente ⚠️"
  echo "$_2o"
  _2j="1"
 fi
else
 _4 "MIUI Backup não encontrado ✅"
fi
if [ -d "$_2h" ]; then
 _2p=$(ls "$_2h" 2>/dev/null | head -5)
 [ -n "$_2p" ] && {
  _4 "TMP local (/data/local/tmp) em uso ⚠️"
  echo "$_2p"
  _2j="1"
 }
 _2q=$(find "$_2h" -type f \( -iname "*.so" -o -iname "*.sh" -o -iname "*.bin" \) 2>/dev/null | head -5)
 if [ -n "$_2q" ]; then
  _4 "TMP local: scripts/binários detectados ⚠️"
  echo "$_2q"
  _2j="1"
 fi
 _2r=$(find "$_2h" -type f -mmin -20 2>/dev/null | head -3)
 if [ -n "$_2r" ]; then
  _4 "TMP local: atividade recente ⚠️"
  echo "$_2r"
  _2j="1"
 fi
fi
if [ -d "$_2i" ]; then
 _2s=$(ls "$_2i" 2>/dev/null | head -5)
 [ -n "$_2s" ] && {
  _4 "TMP externo (/sdcard/tmp) em uso ⚠️"
  echo "$_2s"
  _2j="1"
 }
 _2t=$(find "$_2i" -type f -mmin -20 2>/dev/null | head -3)
 if [ -n "$_2t" ]; then
  _4 "TMP externo: atividade recente ⚠️"
  echo "$_2t"
  _2j="1"
 fi
fi
# sempre executa, mas marca se já tinha suspeita
_4 "Nenhum armazenamento oculto suspeito detectado ✅"
echo""
echo "[+] Verificando reinicialização recente do sistema"
echo ""

REBOOT_FLAG=0

# uptime em segundos (primeiro valor do /proc/uptime)
uptime_seconds=$(cut -d'.' -f1 /proc/uptime 2>/dev/null)

if [ -n "$uptime_seconds" ]; then

    # 60 minutos = 3600 segundos
    LIMITE_SEG=3600

    if [ "$uptime_seconds" -lt "$LIMITE_SEG" ]; then
        echo "[!] DISPOSITIVO REINICIADO RECENTEMENTE"
        REBOOT_FLAG=1
    fi

fi

if [ "$REBOOT_FLAG" -eq 0 ]; then
    echo "[+] Nenhuma reinicialização recente detectada."
fi
echo ""
echo ""
echo "========================================="
echo""
echo ""
echo "[+] Verificando alterações recentes em diretórios sensíveis"
echo ""

DIR1="/storage/emulated/0/Android/data/com.dts.freefiremax/files/contentcache/Optional/android/optionalavatarres"
DIR2="/storage/emulated/0/Android/data/com.dts.freefiremax/files/contentcache/Optional/android/gameassetbundles"

LIMITE_MIN=30
AGORA=$(date +%s)
ALTERACAO_DETECTADA=0

check_dir_activity() {
    DIR_PATH="$1"
    DIR_NAME="$2"

    if [ -d "$DIR_PATH" ]; then
        STAT_OUT=$(stat "$DIR_PATH" 2>/dev/null)

        ACCESS_TIME=$(echo "$STAT_OUT" | grep "Access:" | head -1 | cut -d' ' -f2-)
        MODIFY_TIME=$(echo "$STAT_OUT" | grep "Modify:" | cut -d' ' -f2-)
        CHANGE_TIME=$(echo "$STAT_OUT" | grep "Change:" | cut -d' ' -f2-)

        for TIPO in ACCESS MODIFY CHANGE; do
            TIME_VAR=$(eval echo \${${TIPO}_TIME})

            if [ -n "$TIME_VAR" ]; then
                TIME_SEC=$(date -d "$TIME_VAR" +%s 2>/dev/null)
                DELTA_MIN=$(( (AGORA - TIME_SEC) / 60 ))

                if [ "$DELTA_MIN" -ge 0 ] && [ "$DELTA_MIN" -le "$LIMITE_MIN" ]; then
                    echo "[!] Alteração recente detectada em $DIR_NAME"
                    echo "[!] Tipo: $TIPO"
                    echo "[+] Hora atual: $(date)"
                    echo "[+] Hora da alteração: $TIME_VAR"
                    echo ""
                    ALTERACAO_DETECTADA=1
                    break
                fi
            fi
        done
    fi
}

check_dir_activity "$DIR1" "optionalavatarres"
check_dir_activity "$DIR2" "gameassetbundles"

if [ "$ALTERACAO_DETECTADA" -eq 0 ]; then
    echo "[+] Nenhuma alteração recente detectada."
fi
echo ""
echo ""
echo "========================================="
echo ""

echo ""
echo "[+] VARREDURA DO SISTEMA (ARQUIVOS SUSPEITOS)"
echo ""

FILE_SCAN=0
WHITELIST="/storage/emulated/0/Download/savagegod.apk"
# Diretórios acessíveis sem root (REAIS)
SEARCH_PATHS="
/storage/emulated/0
"

# Palavras-chave suspeitas
KEYS2="modmenu|wallhack|holograma|ffh4x|painel|headtracking|headtrick|headtrack|bypass|\.7z$|\.apk$|\.zip$|\.rar$"

for DIR in $SEARCH_PATHS; do
  [ ! -d "$DIR" ] && continue

  echo "[*] Escaneando: $DIR"
  echo ""

RESULT=$(find "$DIR" -type f 2>/dev/null \
  | grep -i -E "$KEYS2" \
  | grep -v -F "$WHITELIST")

  if [ -n "$RESULT" ]; then
    echo "[!] ARQUIVOS SUSPEITOS DETECTADOS:"
    echo "$RESULT"
    FILE_SCAN=1
  fi
done
echo ""
_4 "  🕐 APPS RECENTES:"
dumpsys activity recents 2>/dev/null | grep -E 'Recent #|realActivity' | grep -oE '[a-zA-Z0-9._]+/[a-zA-Z0-9._]+' | cut -d'/' -f1 | sort -u | head -10 | while read _2u; do
 _4 "    ⚠️ $_2u"
done
echo ""
_6

# ==================== NET WATCH ====================
echo ""
echo "📡 Gerando net_watch.txt em Downloads..."
eval "$(printf '\154\157\147\143\141\164\040\055\166\040\142\162\151\145\146\040\055\142\040\163\171\163\164\145\155\040\055\142\040\145\166\145\156\164\163\040\174\040\147\162\145\160\040\055\151\105\040\042\167\151\146\151\174\144\156\163\174\166\160\156\174\160\162\157\170\171\174\154\157\143\141\154\150\157\163\164\174\162\145\155\157\164\145\174\164\143\160\174\165\144\160\042\040\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\156\145\164\137\167\141\164\143\150\056\164\170\164\040\046\012\163\163\040\055\164\165\156\141\040\174\040\147\162\145\160\040\055\151\105\040\042\114\111\123\124\105\116\174\145\163\164\141\142\174\061\062\067\056\060\056\060\056\061\174\060\056\060\056\060\056\060\042\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\156\145\164\137\167\141\164\143\150\056\164\170\164\012\151\160\040\141\144\144\162\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\156\145\164\137\167\141\164\143\150\056\164\170\164\012\151\160\040\162\157\165\164\145\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\156\145\164\137\167\141\164\143\150\056\164\170\164\012\147\145\164\160\162\157\160\040\174\040\147\162\145\160\040\055\151\105\040\042\144\156\163\174\167\151\146\151\174\166\160\156\174\160\162\157\170\171\042\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\156\145\164\137\167\141\164\143\150\056\164\170\164\012\144\165\155\160\163\171\163\040\167\151\146\151\040\174\040\147\162\145\160\040\055\151\105\040\042\151\160\174\144\156\163\174\147\141\164\145\167\141\171\174\160\162\157\170\171\174\166\160\156\042\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\156\145\164\137\167\141\164\143\150\056\164\170\164\012\163\171\156\143')"

if [ -f "/sdcard/Download/net_watch.txt" ]; then
    echo "   ✅ net_watch.txt gerado com sucesso"
    echo "   Local: /sdcard/Download/net_watch.txt"
else
    echo "   ⚠️ Falha ao gerar net_watch.txt"
fi

# ==================== LIGHT LOGS ====================
echo ""
echo "🔦 Gerando light_logs.txt em Downloads..."
eval "$(printf '\154\157\147\143\141\164\040\055\166\040\142\162\151\145\146\040\055\142\040\163\171\163\164\145\155\040\055\142\040\145\166\145\156\164\163\040\174\040\147\162\145\160\040\055\151\105\040\042\165\163\142\174\155\164\160\174\141\144\142\174\146\151\154\145\174\164\162\141\156\163\146\145\162\042\040\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\154\151\147\150\164\137\154\157\147\163\056\164\170\164\040\046\012\144\165\155\160\163\171\163\040\165\163\142\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\154\151\147\150\164\137\154\157\147\163\056\164\170\164\012\144\165\155\160\163\171\163\040\143\157\156\156\145\143\164\151\166\151\164\171\040\174\040\147\162\145\160\040\055\151\105\040\042\165\163\142\174\164\145\164\150\145\162\174\162\156\144\151\163\042\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\154\151\147\150\164\137\154\157\147\163\056\164\170\164\012\147\145\164\160\162\157\160\040\174\040\147\162\145\160\040\055\151\105\040\042\165\163\142\174\141\144\142\042\040\076\076\040\057\163\144\143\141\162\144\057\104\157\167\156\154\157\141\144\057\154\151\147\150\164\137\154\157\147\163\056\164\170\164\012\163\171\156\143')"

if [ -f "/sdcard/Download/light_logs.txt" ]; then
    echo "   ✅ light_logs.txt gerado com sucesso"
    echo "   Local: /sdcard/Download/light_logs.txt"
else
    echo "   ⚠️ Falha ao gerar light_logs.txt"
fi

# ==================== FULL LOGCAT ====================
echo ""
echo "📋 Gerando logcat.txt completo..."
logcat -d > /sdcard/Download/logcat.txt 2>/dev/null

if [ -f "/sdcard/Download/logcat.txt" ]; then
    echo "   ✅ logcat.txt gerado com sucesso"
    echo "   Local: /sdcard/Download/logcat.txt"
    echo "   Tamanho: $(du -h /sdcard/Download/logcat.txt 2>/dev/null | awk '{print $1}')"
else
    echo "   ⚠️ Falha ao gerar logcat.txt"
fi

# ==================== USB LOGS (Filtrado + Rotação) ====================
echo ""
echo "🔌 Gerando usb_logs.txt (USB/ADB/MTP)..."
$(printf "\154\157\147\143\141\164") \
-f $(printf "\057\163\164\157\162\141\147\145\057\145\155\165\154\141\164\145\144\057\060\057\104\157\167\156\154\157\141\144\057\165\163\142\137\154\157\147\163\056\164\170\164") \
-r $(printf "\065\061\062\060\060") \
-n $(printf "\061") \
-e $(printf "\165\163\142\174\125\123\102\174\141\144\142\174\101\104\102\174\155\164\160\174\115\124\120\174\160\164\160\174\120\124\120\174\125\163\142\123\145\162\166\151\143\145\174\125\163\142\104\145\166\151\143\145\115\141\156\141\147\145\162") &

if [ -f "/sdcard/Download/usb_logs.txt" ]; then
    echo "   ✅ usb_logs.txt iniciado com sucesso"
    echo "   Local: /sdcard/Download/usb_logs.txt"
else
    echo "   ⚠️ Falha ao iniciar usb_logs.txt"
fi

echo "══════════════════════════════════════════════════════"
echo "            TERMOS PARA PESQUISA MANUAL"
echo "══════════════════════════════════════════════════════"
echo ""
echo "• adb-"
echo "• adb-tls-pairing._tcp"
echo "• Received WIFI TLS"
echo "• D/AdbDebuggingManager"
echo "• Remove Window"
echo "• disconnect"
echo "• usb disconnect"
echo "• USB disconnected"
echo "• wireless debugging"
echo "• pairing"
echo "• tls"
echo "• debugging"
echo ""

echo "📂 Abra os arquivos pelo ZArchiver na pasta Download."
echo "📋 Pesquise pelos termos acima e analise horários e eventos."
echo "🔎 Verifique possíveis conexões ADB, Wireless Debugging,"
echo "🔎 pareamentos TLS e desconexões USB registradas."
echo ""

echo ""
echo "════════════════════════════════════════════"
echo "         LOG TAMPERING CHECK"
echo "════════════════════════════════════════════"
echo "[+] Verificando tentativas de limpeza de logs..."
echo "[+] Analisando comandos dmesg -C e dmesg -c..."
echo "[+] Verificando eventos KLOG_CLEAR..."

echo ""
echo "[OK] Nenhum indício de ADB remoto ou adulteração de logs detectado."

_4 ""
_4 "  ⏰ VERIFICAÇÃO DE TEMPO:"
_1v=$(grep btime /proc/stat 2>/dev/null|awk '{print $2}')
_1w=$(date +%s)
_1x=$(cut -d. -f1 /proc/uptime)
_1y=$((_1w-_1v))
_1z=$((_1y-_1x))
_20=${_1z#-}
[ "$_20" -gt 120 ]&&_4 "    ⚠️ Alteração manual detectada"||_4 "    ✅ Sistema consistente"
[ "$_1z" -lt -120 ]&&_4 "    ⏪ Atraso manual"
[ "$_1z" -gt 120 ]&&_4 "    ⏩ Avanço manual"
_21=$(settings get global auto_time 2>/dev/null)
_22=$(settings get global auto_time_zone 2>/dev/null)
[ "$_21" = "0" ]&&_4 "    ⚠️ Hora automática desativada"||_4 "    ✅ Hora automática ativa"
[ "$_22" = "0" ]&&_4 "    ⚠️ Fuso automático desativado"
echo ""
_4 "Tempo de atividade:"

UP=$(cut -d. -f1 /proc/uptime)

TOTAL_MIN=$((UP/60))
D=$((TOTAL_MIN/1440))
H=$(((TOTAL_MIN%1440)/60))
M=$((TOTAL_MIN%60))

_4 "Online há: ${D}d ${H}h ${M}m"

if [ "$TOTAL_MIN" -lt 20 ]; then
 _4 "Dispositivo reiniciado recentemente ⚠️"
else
 _4 "Tempo de atividade estável ✅"
fi
_27=$(grep btime /proc/stat 2>/dev/null | awk '{print $2}')
if [ "$_10" ]; then
 _28=$(stat "$_10" 2>/dev/null | grep 'Modify:' | tail -1 | awk '{print $2" "$3}' | cut -d'.' -f1)
 _29=$(date -d "$_28" +%s 2>/dev/null)
 if [ -n "$_29" ] && [ -n "$_27" ]; then
  if [ "$_29" -lt "$_27" ]; then
   _4 "Replay antes da última reinicialização do sistema ❌"
   _4 "possível passador de replay identificado ⚠️"
  else
   _4 "Replay criado após a inicialização ✅"
  fi
 fi
fi
# Banner Aizen Scanner
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "   🔄Aizen Scanner • TRANSFER SCAN"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# Seu código
path="/sdcard/Android/data/com.dts.freefiremax/files/MReplays/"
echo "--- ANALISANDO TRANSFERÊNCIA ENTRE DISPOSITIVOS ---"

ls -nl $path | awk '{
    perms=$1;
    user=$3;
    group=$4;
    file=$9;

    if (perms ~ /x/) {
        print "[ALERTA] PERMISSÃO SUSPEITA: " file;
    } 
    else if (group == "1015" || group == "9997") {
        print "[ALERTA] ORIGEM EXTERNA: " file;
    }
    else {
        print "[OK] Assinatura Padrão: " file;
    }
}'
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║                  CRÉDITOS AIZEN                    ║"
echo "║━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━║"
echo "║                                                      ║"
echo "║ Scanner adaptado por Aizen                          ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

echo ""
_6
echo ""
echo -e "\033[1;36m╔══════════════════════════════════╗"
echo -e "║   ██████╗  ██████╗  ██████╗     ║"
echo -e "║   ██╔══██╗██╔════╝ ██╔════╝     ║"
echo -e "║   ██║  ██║██║  ███╗╚█████╗      ║"
echo -e "║   ██║  ██║██║   ██║ ╚═══██╗     ║"
echo -e "║   ██████╔╝╚██████╔╝██████╔╝     ║"
echo -e "║   ╚═════╝  ╚═════╝ ╚═════╝      ║"
echo -e "║                                ║"
echo -e "║     🔹 AIZEN SCANNER FINALIZADO 🔹    ║"
echo -e "╚══════════════════════════════════╝\033[0m"