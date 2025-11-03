#!/bin/bash

# ------------------------------------------------------------
# Syncthing + syncthing-gtk установщик для Linux Mint (Cinnamon)
# ------------------------------------------------------------

set -euo pipefail

interactive=true  # true (пошаговые y/N) / false (полная автоматизация)

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
good()  { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1" >&2; }

# === Подготовка системы ===
prepare_system() {
    log "Установка зависимостей: apt-transport-https, ca-certificates..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates
}

# === Работа с официальным репозиторием ===
add_official_repo_v2() {
    log "Добавление GPG-ключа..."
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://syncthing.net/release-key.gpg | gpg --dearmor -o /etc/apt/keyrings/syncthing-archive-keyring.gpg

    log "Добавление репозитория stable-v2..."
    echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | \
        sudo tee /etc/apt/sources.list.d/syncthing.list >/dev/null

    log "Настройка pinning (приоритет пакетов)..."
    printf "Package: *\nPin: origin apt.syncthing.net\nPin-Priority: 990\n" | \
        sudo tee /etc/apt/preferences.d/syncthing.pref >/dev/null

    sudo apt-get update
}

# === Действия ===
update_to_v2() {
    add_official_repo_v2
    sudo apt-get install -y --only-upgrade syncthing
    good "Syncthing обновлён до v2.x (конфиги сохранены)."
}

reinstall_clean_v2() {
    log "Очистка конфигурации Syncthing (~/.config/syncthing)..."
    rm -rf ~/.config/syncthing

    add_official_repo_v2
    sudo apt-get install -y syncthing
    good "Syncthing v2.x установлен с чистой конфигурацией."
}

install_official_v2() {
    add_official_repo_v2
    sudo apt-get install -y syncthing
    good "Syncthing v2.x установлен."
}

install_from_distribution() {
    log "Установка Syncthing из репозитория дистрибутива..."
    sudo apt-get update
    sudo apt-get install -y syncthing
    good "Syncthing установлен из репозитория дистрибутива."
}

install_gtk() {
    log "Установка syncthing-gtk..."
    sudo apt-get install -y syncthing-gtk
    good "syncthing-gtk установлен."
}

setup_autostart_and_run() {
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/syncthing-gtk.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=syncthing-gtk
Hidden=false
NoDisplay=false
Name=Syncthing GTK
Comment=GUI for Syncthing
X-GNOME-Autostart-enabled=true
EOF
    good "Автозапуск настроен."
    nohup syncthing-gtk >/dev/null 2>&1 &
    good "syncthing-gtk запущен."
}

# === Основной поток ===
log "=== Установка Syncthing + GUI для Linux Mint ==="

prepare_system

syncthing_exists=false
if command -v syncthing >/dev/null 2>&1; then
    syncthing_exists=true
fi

# ----------------------------
# НЕИНТЕРАКТИВНЫЙ РЕЖИМ
# ----------------------------
if [[ "$interactive" == false ]]; then
    log "Режим: неинтерактивный"
    if $syncthing_exists; then
        # В автоматическом режиме при наличии — переустановка с чистого листа
        reinstall_clean_v2
    else
        install_official_v2
    fi
    install_gtk
    setup_autostart_and_run
    good "✅ Готово: Syncthing v2.x + GUI + автозапуск."
    exit 0
fi

# ----------------------------
# ИНТЕРАКТИВНЫЙ РЕЖИМ
# ----------------------------

if $syncthing_exists; then
    current_ver=$(syncthing --version 2>/dev/null | head -n1 || echo "неизвестна")
    warn "Syncthing уже установлен (версия: $current_ver)."
    warn "Внимание: переход на v2.x НЕОБРАТИМ — откат невозможен!"

    read -p "Обновить до Syncthing v2.x с сохранением конфигурации? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_to_v2
    else
        read -p "Переустановить Syncthing v2.x с ПОЛНЫМ СБРОСОМ настроек? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            reinstall_clean_v2
        else
            good "Текущая установка Syncthing оставлена без изменений."
        fi
    fi
else
    read -p "Установить Syncthing v2.x из официального репозитория? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_official_v2
    else
        read -p "Установить Syncthing из репозитория дистрибутива? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_from_distribution
        else
            error "Syncthing не установлен. GUI невозможен."
            exit 1
        fi
    fi
fi

# Проверка доступности Syncthing
if ! command -v syncthing >/dev/null 2>&1; then
    error "Syncthing недоступен. Завершение."
    exit 1
fi

# Установка GUI
read -p "Установить syncthing-gtk (графический интерфейс)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_gtk
else
    error "GUI не установлен. Завершение."
    exit 1
fi

# Автозапуск
read -p "Настроить автозапуск и запустить syncthing-gtk сейчас? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_autostart_and_run
else
    good "Готово. Запустите 'Syncthing GTK' вручную из меню."
fi

good "🎉 Установка завершена!"
