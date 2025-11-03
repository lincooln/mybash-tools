#!/bin/bash
# скрипт написан и протестирован на debian 13. на других системах не проверялся, но в большинстве случаев должен работать корректно.
# цель скрипта рашарить нужную папку/папки с помощю одной команды. все нужные настройки задаются в этом скрипте.
# настройки можно пререопределять каждый раз при запуске скрипта, для этого надо удалить любое из значений (например пароль пользователя)
# !ВАЖНО! Каждый запуск скрипта удаляет любые другие настройки связанные с Samba. Так задумано.

# === НАЧАЛО НАСТРОЕК (редактируйте здесь) ===
# Пути для расшаривания (массив; поддерживается ~)
share_paths=("~/media" "")
share_name=""   # Имя SMB-шары (оставьте пустым для использования hostname)
smb_user="user" # имя пользователя
smb_pass="123"  # пароль пользователя
guest_mode=true # true подключение возможно как гость, и по логину/паролю. false только по логину/паролю
share_printers=false # Расшаривать принтеры через Samba? Будет так же установлен CUPS
delete_samba_share=false # поменяйте на true для удаления все настроек samba а так же пакеты из системы
dir_permissions="777" # права 777 можно всем читать/писать)
# === КОНЕЦ НАСТРОЕК ===

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Интерактивный ввод с подсказкой и значением по умолчанию
prompt_default() {
    local var_name="$1"
    local default_val="$2"
    local description="$3"
    read -rp "$(printf "%s [%s]: " "$description" "$default_val")" input
    echo "${input:-$default_val}"
}

# Автоматический запрос sudo, если не root
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        echo "Запрашиваются права root через sudo..."
        exec sudo "$0" "$@"
    else
        echo "[ERROR] Этот скрипт требует прав root. Установите sudo или запустите от root." >&2
        exit 1
    fi
fi

# Определяем hostname как fallback для имени шары
hostname_fallback="$(hostname)"

# -------------------------------
# ИНТЕРАКТИВНЫЙ РЕЖИМ (если нужно)
# -------------------------------
# Проверяем, заданы ли все обязательные параметры
need_interactive=false

# Проверяем массив share_paths
if [[ ${#share_paths[@]} -eq 0 || -z "${share_paths[0]// }" ]]; then
    need_interactive=true
fi

# Проверяем остальные
[[ -z "$smb_user" ]] && need_interactive=true
[[ -z "$smb_pass" ]] && need_interactive=true
# share_name может быть пустым — это нормально

if $need_interactive; then
    log "Не все параметры заданы. Запускаем интерактивный режим."

    # Пути
    echo "Введите пути для расшаривания (разделите пробелами, ~ разрешён):"
    read -ra input_paths
    share_paths=("${input_paths[@]:-("~")}")

    # Имя шары
    share_name=$(prompt_default "share_name" "$share_name" "Имя SMB-шары (пусто = $hostname_fallback)")
    [[ -z "$share_name" ]] && share_name="$hostname_fallback"

    # Пользователь
    smb_user=$(prompt_default "smb_user" "$smb_user" "Имя Samba-пользователя")
    smb_pass=$(prompt_default "smb_pass" "$smb_pass" "Пароль Samba-пользователя")

    # Гостевой режим
    read -rp "Разрешить гостевой доступ? (y/N): " -n 1 -s guest_resp
    echo
    guest_mode=false
    [[ "$guest_resp" =~ ^[Yy]$ ]] && guest_mode=true

    # Принтеры
    read -rp "Расшаривать принтеры? (y/N): " -n 1 -s printer_resp
    echo
    share_printers=false
    [[ "$printer_resp" =~ ^[Yy]$ ]] && share_printers=true
else
    [[ -z "$share_name" ]] && share_name="$hostname_fallback"
fi

# -------------------------------
# РЕЖИМ УДАЛЕНИЯ
# -------------------------------
if [[ "$delete_samba_share" == true ]]; then
    log "Режим удаления: удаляем Samba и связанные компоненты..."
    apt remove --purge -y samba smbclient
    apt autoremove --purge -y

    # Удаляем остатки вручную (на всякий случай)
    rm -rf /etc/samba/ /var/lib/samba/ /run/samba/
    userdel -r "$smb_user" 2>/dev/null || true

    log "Samba полностью удалена. Готово."
    exit 0
fi

# -------------------------------
# УСТАНОВКА ЗАВИСИМОСТЕЙ
# -------------------------------
log "Установка необходимых пакетов..."

apt update -y

# Основной пакет
apt install -y samba

# Принтеры, проверяем наличие CUPS
if [[ "$share_printers" == true ]]; then
    if systemctl is-active --quiet cups 2>/dev/null || systemctl is-enabled --quiet cups 2>/dev/null; then
        log "CUPS обнаружен. Принтеры будут расшарены."
    else
        warn "CUPS не установлен. Принтеры расшарены не будут."
        share_printers=false  # отключаем, чтобы не генерировать секции
    fi
fi

# -------------------------------
# СОЗДАНИЕ СИСТЕМНОГО ПОЛЬЗОВАТЕЛЯ
# -------------------------------
log "Создание системного пользователя '$smb_user' (если не существует)..."

if ! id "$smb_user" &>/dev/null; then
    useradd -m -s /bin/bash "$smb_user"
fi

# -------------------------------
# НАСТРОЙКА ПУТЕЙ
# -------------------------------
log "Обработка путей для расшаривания..."

expanded_paths=()
for raw_path in "${share_paths[@]}"; do
    # Раскрываем ~ (осторожно!)
    if [[ "$raw_path" == ~* ]]; then
        # Используем eval только для ~, остальное не трогаем
        expanded_path="$(eval echo "$raw_path")"
    else
        expanded_path="$raw_path"
    fi

    # Создаём директорию, если не существует
    mkdir -p "$expanded_path"

    # Меняем владельца
    chown "$smb_user:$smb_user" "$expanded_path"

    # Назначаем права директории
    chmod "$dir_permissions" "$expanded_path"

    expanded_paths+=("$expanded_path")
done

# -------------------------------
# НАСТРОЙКА SAMBA-ПОЛЬЗОВАТЕЛЯ
# -------------------------------
log "Настройка Samba-пользователя '$smb_user'..."

# Удаляем старую запись, если есть (чтобы избежать ошибок)
smbpasswd -x "$smb_user" 2>/dev/null || true

# Создаём заново
(echo "$smb_pass"; echo "$smb_pass") | smbpasswd -a -s "$smb_user"

# -------------------------------
# ГЕНЕРАЦИЯ КОНФИГУРАЦИИ
# -------------------------------
log "Генерация конфигурации Samba..."

smb_config="/etc/samba/smb.conf"

# Минимальный глобальный конфиг
{
    echo "[global]"
    echo "   workgroup = WORKGROUP"
    echo "   server string = Samba Server"
    echo "   server role = standalone server"
    echo "   obey pam restrictions = yes"
    echo "   unix password sync = yes"
    echo "   pam password change = yes"
    echo "   map to guest = bad user"
    echo "   usershare allow guests = yes"
    echo "   security = user"
    echo "   guest account = nobody"
    echo "   load printers = $( [[ "$share_printers" == true ]] && echo "yes" || echo "no" )"
    echo "   printing = $( [[ "$share_printers" == true ]] && echo "cups" || echo "bsd" )"
    echo "   printcap name = $( [[ "$share_printers" == true ]] && echo "/etc/printcap" || echo "/dev/null" )"
    echo "   disable spoolss = $( [[ "$share_printers" == false ]] && echo "yes" || echo "no" )"
    echo
} > "$smb_config"

# Секции принтеров
if [[ "$share_printers" == true ]]; then
    {
        echo "[printers]"
        echo "   comment = All Printers"
        echo "   browseable = no"
        echo "   path = /var/spool/samba"
        echo "   printable = yes"
        echo "   guest ok = yes"
        echo "   read only = yes"
        echo "   create mask = 0700"
        echo
        echo "[print$]"
        echo "   comment = Printer Drivers"
        echo "   path = /var/lib/samba/printers"
        echo "   browseable = yes"
        echo "   read only = yes"
        echo "   guest ok = no"
        echo
    } >> "$smb_config"
fi

# Секции шар
for path in "${expanded_paths[@]}"; do
    {
        echo "[$share_name$( [[ ${#expanded_paths[@]} -gt 1 ]] && echo "_$(basename "$path")" )]"
        echo "   path = $path"
        echo "   browsable = yes"
        echo "   writable = yes"
        echo "   read only = no"
        echo "   guest ok = $( [[ "$guest_mode" == true ]] && echo "yes" || echo "no" )"
        echo "   valid users = $smb_user"
        echo "   create mask = 0777"
        echo "   directory mask = 0777"
        echo
    } >> "$smb_config"
done

# -------------------------------
# ПЕРЕЗАПУСК СЛУЖБ
# -------------------------------
log "Перезапуск служб Samba..."

systemctl enable --now smbd nmbd
systemctl restart smbd nmbd

if [[ "$share_printers" == true ]]; then
    systemctl restart cups
fi

log "Samba настроена успешно!"
log "Шара(ы): $share_name"
log "Пути: ${expanded_paths[*]}"
log "Пользователь: $smb_user / Пароль: $smb_pass"
[[ "$guest_mode" == true ]] && log "Гостевой доступ: разрешён"
log "Конфигурация: $smb_config"

exit 0
