#!/bin/bash
# SyncthingTray Installer for ALT Linux and derivatives
# Версия 5.4 — финальная, для пользователей
# Автор: Lincooln, с участием Qwen3-Max
# ==================================================

# === Настройки (измените при необходимости) ===
# Адреса где берём архивы текущий и резервный
DOWNLOAD_URL="https://github.com/Martchus/syncthingtray/releases/download/v2.0.2/syncthingtray-2.0.2-x86_64-pc-linux-gnu.tar.xz"
OLD_DOWNLOAD_URL="https://github.com/Martchus/syncthingtray/releases/download/v2.0.1/syncthingtray-2.0.1-x86_64-pc-linux-gnu.tar.xz"
# Директории для установки
ROOT_DIR="/opt/syncthingtray"
USER_DIR="$HOME/bin/syncthingtray"
# ==============================================

set -e

# Глобальные переменные
TEMP_DIR=""
CURRENT_URL="$DOWNLOAD_URL"
FALLBACK_URL="$OLD_DOWNLOAD_URL"
ARCHIVE_PATH=""

# --------------------------------------------------
# Вспомогательные функции
# --------------------------------------------------

is_yes() {
    [[ "$1" =~ ^([yYдД])$ ]]
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "altlinux" ]] || [[ "$ID_LIKE" == *"altlinux"* ]]; then
            echo "✅ Обнаружена система на базе ALT Linux ($VERSION_ID)"
            return 0
        else
            echo "⚠️  Обнаружена ОС: $PRETTY_NAME"
            echo "ℹ️  Этот скрипт предназначен для ALT Linux и производных."
            read -p "Продолжить на свой риск? (y/д — да, n/н — нет): " -r
            if ! is_yes "$REPLY"; then
                echo "Отмена по запросу пользователя."
                exit 0
            fi
        fi
    else
        echo "⚠️  Не удалось определить ОС."
        read -p "Продолжить? (y/д — да, n/н — нет): " -r
        if ! is_yes "$REPLY"; then exit 0; fi
    fi
}

detect_user_mode() {
    if [[ $EUID -eq 0 ]] && [[ -n "$SUDO_USER" ]] && [[ "$HOME" == "/root" ]]; then
        echo "⚠️  Вы запустили скрипт через sudo."
        echo "    Это приведёт к установке в /opt и настройке ТОЛЬКО для root."
        echo "    Рекомендуется запускать ОТ СВОЕГО ПОЛЬЗОВАТЕЛЯ:"
        echo "        ./$0"
        read -p "Продолжить как root? (y/д — да, n/н — нет): " -r
        if ! is_yes "$REPLY"; then exit 0; fi
    fi

    if [[ $EUID -eq 0 ]]; then
        INSTALL_DIR="$ROOT_DIR"
        DESKTOP_DIR="/usr/share/applications"
        SYSTEM_MODE=true
    else
        INSTALL_DIR="$USER_DIR"
        DESKTOP_DIR="$HOME/.local/share/applications"
        SYSTEM_MODE=false
    fi
}

check_installed() {
    if [[ -f "$INSTALL_DIR/syncthingtray" ]]; then
        echo "🔄 Обнаружена установленная версия в: $INSTALL_DIR"
        echo "Выберите действие:"
        echo "  1 — Обновить"
        echo "  2 — Удалить"
        echo "  0 — Отмена"
        read -p "Ваш выбор (1/2/0): " -r
        case "$REPLY" in
            2) uninstall_app; exit 0 ;;
            1) MODE="обновление"; return 0 ;;
            *) echo "Отмена."; exit 0 ;;
        esac
    else
        MODE="установка"
        echo "🆕 SyncthingTray не установлен."
    fi
}

ensure_archive_tools() {
    local missing=()
    for tool in tar unzip file; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌ Отсутствуют необходимые утилиты: ${missing[*]}"
        read -p "Установить через apt-get? (y/д — да): " -r
        if is_yes "$REPLY"; then
            if [[ "$SYSTEM_MODE" == true ]]; then
                apt-get update && apt-get install -y "${missing[@]}"
            elif command -v sudo &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y "${missing[@]}"
            else
                echo "⚠️  sudo не настроен. Выполните:"
                echo "   su -c 'apt-get update && apt-get install -y ${missing[*]}'"
                exit 1
            fi
        else
            echo "Выход: невозможно продолжить без необходимых утилит."
            exit 1
        fi
    fi
}

# 🔑 ИСПРАВЛЕНО: безопасный поиск архива с пробелами и спецсимволами
find_local_archive() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local -a candidates=()
    local file

    while IFS= read -r -d '' file; do
        if [[ "$file" =~ \.(tar\.xz|tar\.gz|zip)$ ]]; then
            local basename
            basename=$(basename "$file" | tr '[:upper:]' '[:lower:]')
            if [[ "$basename" == *"syncthingtray"* ]]; then
                candidates+=("$file")
            fi
        fi
    done < <(find "$script_dir" -maxdepth 1 -type f \( -name "*.tar.xz" -o -name "*.tar.gz" -o -name "*.zip" \) -print0)

    if [[ ${#candidates[@]} -eq 0 ]]; then
        return 1
    elif [[ ${#candidates[@]} -gt 1 ]]; then
        echo "❌ Найдено несколько кандидатов:"
        printf '  - %s\n' "${candidates[@]}"
        echo "Оставьте один архив рядом со скриптом."
        exit 1
    fi

    local candidate="${candidates[0]}"
    if tar -tf "$candidate" 2>/dev/null | grep -q "syncthingtray"; then
        echo "$candidate"
        return 0
    else
        echo "❌ 'syncthingtray' не найден в архиве: $(basename "$candidate")"
        return 1
    fi
}

check_github_connectivity() {
    if command -v curl &>/dev/null; then
        curl -sf --connect-timeout 5 --max-time 10 https://github.com/ >/dev/null 2>&1
    elif command -v wget &>/dev/null; then
        wget -q --spider --timeout=5 --tries=1 https://github.com/ 2>/dev/null
    else
        return 1
    fi
}

ensure_network_tools() {
    if command -v wget &>/dev/null || command -v curl &>/dev/null; then
        return 0
    fi
    echo "❌ Отсутствует wget или curl для онлайн-операций."
    read -p "Установить wget через apt-get? (y/д — да): " -r
    if is_yes "$REPLY"; then
        if [[ "$SYSTEM_MODE" == true ]]; then
            apt-get update && apt-get install -y wget
        elif command -v sudo &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y wget
        else
            echo "⚠️  sudo не настроен. Выполните:"
            echo "   su -c 'apt-get update && apt-get install -y wget'"
            exit 1
        fi
    else
        echo "Без wget/curl невозможно проверить обновления или скачать архив."
        exit 1
    fi
}

fetch_latest_release_url() {
    local api_url="https://api.github.com/repos/Martchus/syncthingtray/releases/latest"
    if command -v curl &>/dev/null; then
        curl -s "$api_url" | grep -o '"browser_download_url": "[^"]*x86_64-pc-linux-gnu\.tar\.xz"' | head -n1 | cut -d'"' -f4
    elif command -v wget &>/dev/null; then
        wget -qO- "$api_url" | grep -o '"browser_download_url": "[^"]*x86_64-pc-linux-gnu\.tar\.xz"' | head -n1 | cut -d'"' -f4
    fi
}

# 🔑 ИСПРАВЛЕНО: понятное сообщение
offer_to_update_url() {
    local latest_url="$1"
    local current_version latest_version

    current_version=$(echo "$CURRENT_URL" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    latest_version=$(echo "$latest_url" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+')

    if [[ -z "$current_version" ]] || [[ -z "$latest_version" ]]; then
        echo "⚠️  Не удалось определить версии. Используем текущую ссылку."
        return 0
    fi

    if [[ "$latest_version" > "$current_version" ]]; then
        echo "🆕 Доступна новая версия: $latest_version (текущая: $current_version)"
        read -p "Обновить ссылку и использовать новую версию? (y/д — да): " -r
        if is_yes "$REPLY"; then
            FALLBACK_URL="$CURRENT_URL"
            CURRENT_URL="$latest_url"
            echo "ℹ️  Переключаемся на: $CURRENT_URL"
        fi
    else
        echo "ℹ️  Текущая ссылка указывает на последнюю версию: $current_version"
    fi
}

download_archive_with_retries() {
    local url="$1"
    local dest="$2"
    local max_retries=3
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        if [[ $attempt -gt 1 ]]; then
            echo "🔁 Попытка $attempt из $max_retries..."
        fi

        if wget --quiet --show-progress --progress=bar:force:noscroll -O "$dest" "$url" 2>&1; then
            echo
            echo "✅ Архив успешно скачан."
            return 0
        else
            echo
            echo "❌ Попытка $attempt не удалась."
            if [[ $attempt -lt $max_retries ]]; then
                sleep 2
            fi
        fi
        ((attempt++))
    done
    return 1
}

validate_binary_and_deps() {
    local bin="$1"
    if [[ ! -f "$bin" ]]; then
        echo "❌ Бинарный файл не найден: $bin"
        return 1
    fi
    local file_output
    file_output=$(file "$bin" 2>/dev/null)
    if [[ "$file_output" != *"ELF"* ]] || [[ "$file_output" != *"executable"* ]]; then
        echo "❌ Файл не является исполняемым ELF-бинарником."
        echo "   Вывод 'file': $file_output"
        return 1
    fi
    local missing
    missing=$(ldd "$bin" 2>/dev/null | grep "not found" | awk '{print $1}')
    if [[ -n "$missing" ]]; then
        echo "❌ Обнаружены неразрешённые зависимости:"
        echo "$missing" | while IFS= read -r lib; do
            [[ -n "$lib" ]] && echo "  - $lib"
        done
        return 1
    fi
    echo "✅ Проверка зависимостей завершена."
    return 0
}

extract_and_validate() {
    local archive="$1"
    local out_dir="$2"

    echo "📦 Распаковываем архив..."
    if [[ "$archive" == *.zip ]]; then
        unzip -q "$archive" -d "$out_dir"
    else
        tar -xf "$archive" -C "$out_dir"
    fi
    echo "✅ Архив распакован."

    BINARY=$(find "$out_dir" -type f -name "syncthingtray" 2>/dev/null | head -n1)
    if [[ -z "$BINARY" ]]; then
        echo "❌ Файл 'syncthingtray' не найден в архиве."
        echo "   Содержимое распакованной директории:"
        find "$out_dir" -type f | sed 's/^/     /' || echo "     (пусто)"
        return 1
    fi
    echo "✅ Найден бинарник: $(realpath --relative-to="$out_dir" "$BINARY")"

    echo "🔍 Проверка совместимости..."
    validate_binary_and_deps "$BINARY"
}

install_app() {
    local src_dir="$1"
    mkdir -p "$INSTALL_DIR"
    cp "$BINARY" "$INSTALL_DIR/syncthingtray"
    chmod +x "$INSTALL_DIR/syncthingtray"

    local syncthing_bin
    syncthing_bin=$(dirname "$BINARY")/syncthing
    if [[ -f "$syncthing_bin" ]]; then
        cp "$syncthing_bin" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/syncthing"
        echo "✅ Встроенный Syncthing установлен."
    fi

    mkdir -p "$DESKTOP_DIR"
    cat <<EOF > "$DESKTOP_DIR/syncthingtray.desktop"
[Desktop Entry]
Name=Syncthing Tray
Comment=Tray icon and integration for Syncthing
Exec=$INSTALL_DIR/syncthingtray
Icon=network-sync
Terminal=false
Type=Application
Categories=Network;System;
StartupNotify=false
Keywords=sync;syncthing;tray;
StartupWMClass=syncthingtray
X-KDE-UniqueApp=true
X-GNOME-Autostart-enabled=true
EOF

    if command -v kbuildsycoca5 &>/dev/null; then
        kbuildsycoca5 &>/dev/null || true
    elif command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$DESKTOP_DIR" &>/dev/null || true
    fi
}

uninstall_app() {
    if pgrep -x "syncthingtray" > /dev/null; then
        echo "⏹️  Останавливаем запущенный SyncthingTray..."
        pkill -x "syncthingtray"
        sleep 1
    fi

    echo "🗑️  Удаление SyncthingTray из $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    rm -f "$DESKTOP_DIR/syncthingtray.desktop"

    if command -v kbuildsycoca5 &>/dev/null; then
        kbuildsycoca5 &>/dev/null || true
    elif command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$DESKTOP_DIR" &>/dev/null || true
    fi

    echo "✅ Удаление завершено."
    echo "ℹ️  Настройки в ~/.config/syncthing* сохранены."
}

cleanup() {
    [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    [[ -n "$TEMP_ARCHIVE" && -f "$TEMP_ARCHIVE" ]] && rm -f "$TEMP_ARCHIVE"
}
trap cleanup EXIT INT TERM

# --------------------------------------------------
# Основной поток
# --------------------------------------------------

main() {
    echo "=== SyncthingTray: установка на ALT Linux ==="

    detect_os
    detect_user_mode
    check_installed
    ensure_archive_tools

    if local_archive=$(find_local_archive 2>/dev/null); then
        echo "📁 Используем локальный архив: $(basename "$local_archive")"
        ARCHIVE_PATH="$local_archive"
    else
        echo "📁 Локальный архив не найден."

        echo "🌐 Проверяем доступность github.com..."
        if check_github_connectivity; then
            echo "✅ github.com доступен."
        else
            echo "❌ github.com недоступен. Возможно, нет интернета или блокировка."
            echo
            echo "ℹ️  Пожалуйста, скачайте архив вручную:"
            echo "    • https://martchus.github.io/syncthingtray/#downloads-section"
            echo "    • https://github.com/Martchus/syncthingtray/releases"
            echo
            echo "    Сохраните его в ту же папку, где находится этот скрипт,"
            echo "    и запустите скрипт снова."
            exit 1
        fi

        ensure_network_tools

        # 🔑 ИСПРАВЛЕНО: понятное сообщение перед проверкой
        echo "🔍 Проверяем наличие новой версии..."
        if latest_url=$(fetch_latest_release_url); then
            if [[ -n "$latest_url" ]] && [[ "$latest_url" != "$CURRENT_URL" ]]; then
                offer_to_update_url "$latest_url"
            fi
        else
            echo "⚠️  Не удалось получить информацию о последней версии."
        fi

        max_attempts=2
        attempt=1
        while [[ $attempt -le $max_attempts ]]; do
            TEMP_ARCHIVE="/tmp/syncthingtray-download-$$"
            if download_archive_with_retries "$CURRENT_URL" "$TEMP_ARCHIVE"; then
                ARCHIVE_PATH="$TEMP_ARCHIVE"
                break
            else
                if [[ $attempt -eq 1 ]] && [[ -n "$FALLBACK_URL" ]] && [[ "$CURRENT_URL" != "$FALLBACK_URL" ]]; then
                    echo
                    echo "❓ Не удалось скачать новую версию."
                    echo "   Хотите попробовать последнюю известную рабочую версию?"
                    read -p "(y/д — да): " -r
                    if is_yes "$REPLY"; then
                        CURRENT_URL="$FALLBACK_URL"
                        attempt=$((attempt + 1))
                        continue
                    fi
                fi
                echo "❌ Не удалось скачать ни по одной ссылке."
                exit 1
            fi
        done
    fi

    TEMP_DIR="/tmp/syncthingtray-extract-$$"
    mkdir -p "$TEMP_DIR"

    if ! extract_and_validate "$ARCHIVE_PATH" "$TEMP_DIR"; then
        if [[ "$CURRENT_URL" != "$FALLBACK_URL" ]] && [[ -n "$FALLBACK_URL" ]]; then
            echo
            echo "❓ Проверка новой версии не пройдена:"
            echo "   - Архив может быть повреждён"
            echo "   - Версия несовместима с системой"
            echo "   - Скачан пустой файл (проверьте ссылку на пробелы!)"
            echo
            echo "   Попробовать установить последнюю известную рабочую версию?"
            read -p "(y/д — да): " -r
            if is_yes "$REPLY"; then
                CURRENT_URL="$FALLBACK_URL"
                rm -rf "$TEMP_DIR"
                TEMP_ARCHIVE="/tmp/syncthingtray-download-$$"
                if ! download_archive_with_retries "$CURRENT_URL" "$TEMP_ARCHIVE"; then
                    echo "❌ Даже резервная версия недоступна."
                    exit 1
                fi
                mkdir -p "$TEMP_DIR"
                if ! extract_and_validate "$TEMP_ARCHIVE" "$TEMP_DIR"; then
                    echo "❌ Даже резервная версия несовместима с системой."
                    exit 1
                fi
            else
                exit 1
            fi
        else
            echo "❌ Установка невозможна: нет совместимой версии."
            exit 1
        fi
    fi

    install_app "$TEMP_DIR"

    echo
    if [[ "$MODE" == "установка" ]]; then
        echo "🎉 Установка завершена!"
    else
        echo "✅ Обновление завершено!"
    fi
    echo
    echo "ℹ️  Настройки: ~/.config/syncthing*"
    echo "➡️  Запуск: $INSTALL_DIR/syncthingtray"
}

main "$@"
