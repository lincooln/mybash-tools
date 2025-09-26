#!/bin/bash
# Скрипт для автоматической загрузки, обработки и установки шрифтов.
# Версия 2.0
# Автор: Lincooln, с участием Qwen3-Max

# Определяем директорию, в которой находится скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Папка для временного хранения распакованных шрифтов
DEST="$SCRIPT_DIR/fonts"
mkdir -p "$DEST"

# Список шрифтов для загрузки.
# Формат каждой строки: "URL|имя_локального_архива|имя_папки_после_распаковки"
# Если рядом со скриптом лежит архив с указанным именем и он валиден,
# скрипт не будет скачивать шрифт из интернета.
fonts=(
    # Terminus (Nerd Font) — моноширинный шрифт для терминала с поддержкой иконок
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Terminus.zip|terminus.zip|Terminus"

    # Cascadia Code — современный моноширинный шрифт от Microsoft с поддержкой иконок
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip|cascadia.zip|CascadiaCode"

    # JetBrains Mono — шрифт для программистов с поддержкой лигатур и иконок
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip|jetbrains.zip|JetBrainsMono"

    # Fira Code — популярный шрифт для кода с лигатурами и иконками
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip|fira.zip|FiraCode"

    # Inter — универсальный шрифт без засечек, подходит для интерфейсов (например, Obsidian)
    "https://github.com/rsms/inter/releases/download/v3.19/Inter-3.19.zip|inter.zip|Inter"

    # PT Sans — русскоязычный шрифт, разработанный ParaType, подходит для текстов
    "https://github.com/desero/pt-sans/archive/refs/heads/master.zip|pt-sans-alt.zip|PTSans"

    # IBM Plex Sans — корпоративный шрифт от IBM, хорошо читается на экране
    "https://github.com/IBM/plex/releases/latest/download/ibm-plex-sans.zip|plex.zip|IBMPlexSans"

    # Noto Sans — универсальный шрифт от Google, покрывает множество языков
    "https://noto-website-2.storage.googleapis.com/pkgs/NotoSans-unhinted.zip|noto.zip|NotoSans"

    # Digital-7 — моноширинный цифровой шрифт, имитирующий семисегментный дисплей
    "https://www.1001fonts.com/download/digital-7.zip|digital7.zip|Digital7"

    # Charis SIL — шрифт с засечками, разработанный для лингвистики и поддержки множества языков
    "https://software.sil.org/downloads/r/charis/CharisSIL-6.200.zip|charis.zip|CharisSIL"
)

# === ФУНКЦИИ ===

# Проверка наличия интернет-соединения
# Возвращает "true", если есть доступ к google.com или github.com; иначе — "false"
check_internet() {
    if ping -c 1 -W 3 google.com >/dev/null 2>&1 || ping -c 1 -W 3 github.com >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

# Определение дистрибутива Linux и соответствующего пакетного менеджера
detect_distro() {
    local pkg_manager="unknown"
    local install_cmd=""
    local distro_name="Неизвестный дистрибутив"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro_name="$PRETTY_NAME"

        case "$ID" in
            ubuntu|debian|linuxmint|raspbian)
                pkg_manager="apt"
                install_cmd="apt update && apt install -y"
                ;;
            fedora|rhel|centos|almalinux|rocky)
                if command -v dnf &> /dev/null; then
                    pkg_manager="dnf"
                    install_cmd="dnf install -y"
                else
                    pkg_manager="yum"
                    install_cmd="yum install -y"
                fi
                ;;
            arch|manjaro|endeavouros)
                pkg_manager="pacman"
                install_cmd="pacman -S --noconfirm"
                ;;
            altlinux)
                pkg_manager="urpmi"
                install_cmd="urpmi --auto"
                ;;
            redos)
                pkg_manager="apt-get"
                install_cmd="apt-get update && apt-get install -y"
                ;;
            opensuse*|suse)
                pkg_manager="zypper"
                install_cmd="zypper install -y"
                ;;
        esac
    fi

    # Сохраняем результаты в глобальные переменные
    DETECTED_PKG_MANAGER="$pkg_manager"
    DETECTED_INSTALL_CMD="$install_cmd"
    DETECTED_DISTRO_NAME="$distro_name"
}

# Проверка прав доступа для установки пакетов
check_privileges() {
    local can_install=false
    local sudo_prefix=""

    if [ "$EUID" -eq 0 ]; then
        # Работа от root — не рекомендуется, но допустима
        can_install=true
        PRIVILEGE_STATUS="root"
    elif sudo -n true 2>/dev/null; then
        # sudo настроен без пароля
        can_install=true
        sudo_prefix="sudo "
        PRIVILEGE_STATUS="sudo_nopass"
    else
        # Запрашиваем пароль sudo
        if sudo -v 2>/dev/null; then
            can_install=true
            sudo_prefix="sudo "
            PRIVILEGE_STATUS="sudo_withpass"
        else
            can_install=false
            PRIVILEGE_STATUS="no_access"
        fi
    fi

    CAN_INSTALL="$can_install"
    SUDO_PREFIX="$sudo_prefix"
}

# Установка недостающих зависимостей через пакетный менеджер
install_missing_deps() {
    local missing=("$@")
    local full_cmd="$DETECTED_INSTALL_CMD ${missing[*]}"

    echo "Устанавливаются недостающие зависимости: ${missing[*]}"

    if [ "$EUID" -eq 0 ]; then
        eval "$full_cmd"
    else
        sudo sh -c "$full_cmd"
    fi

    # Проверяем, все ли зависимости установлены
    local failed=()
    for dep in "${missing[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            failed+=("$dep")
        fi
    done

    if [ ${#failed[@]} -eq 0 ]; then
        return 0
    else
        echo "Не удалось установить следующие компоненты: ${failed[*]}"
        return 1
    fi
}

# Проверка наличия необходимых утилит: wget, zip, unzip, find, fc-cache
check_dependencies() {
    local deps=("wget" "zip" "unzip" "find" "fc-cache")
    local missing=()

    echo "Проверка наличия необходимых утилит..."

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "Все необходимые утилиты установлены."
        return 0
    fi

    echo "Отсутствуют следующие утилиты: ${missing[*]}"

    detect_distro
    check_privileges

    if [ "$CAN_INSTALL" = true ] && [ "$DETECTED_PKG_MANAGER" != "unknown" ]; then
        echo "Обнаружен дистрибутив: $DETECTED_DISTRO_NAME"
        echo "Пакетный менеджер: $DETECTED_PKG_MANAGER"

        read -p "Хотите автоматически установить недостающие зависимости? (Y/n): " -n 1 -r install_deps
        echo

        if [[ $install_deps =~ ^[Yy]$ ]]; then
            if install_missing_deps "${missing[@]}"; then
                return 0
            else
                echo "Не удалось установить зависимости. Обратитесь к системному администратору."
                exit 1
            fi
        else
            echo "Установите зависимости вручную с помощью команды:"
            echo "$SUDO_PREFIX$DETECTED_INSTALL_CMD ${missing[*]}"
            exit 1
        fi
    else
        if [ "$DETECTED_PKG_MANAGER" = "unknown" ]; then
            echo "Не удалось определить пакетный менеджер для вашего дистрибутива: $DETECTED_DISTRO_NAME"
        fi
        if [ "$CAN_INSTALL" = false ]; then
            echo "У вас недостаточно прав для установки пакетов."
        fi
        echo "Обратитесь к системному администратору и запросите установку следующих пакетов:"
        echo "${missing[*]}"
        exit 1
    fi
}

# Подсчёт количества валидных локальных архивов
check_existing_archives() {
    local count=0
    for font_info in "${fonts[@]}"; do
        IFS='|' read -r _ filename _ <<< "$font_info"
        if [ -f "$SCRIPT_DIR/$filename" ] && unzip -tq "$SCRIPT_DIR/$filename" >/dev/null 2>&1; then
            ((count++))
        fi
    done
    echo "$count"
}

# Вывод справки по использованию локальных архивов
show_local_archive_help() {
    echo
    echo "Скрипт может работать без интернета, если рядом со скриптом находятся архивы шрифтов."
    echo "Ожидаемые имена архивов:"
    for font_info in "${fonts[@]}"; do
        IFS='|' read -r _ filename foldername <<< "$font_info"
        echo "  - $filename → будет распакован в папку '$foldername'"
    done
    echo "Поместите архивы в ту же директорию, что и скрипт, и перезапустите его."
}

# Вывод справки при неудачной загрузке шрифтов
show_download_failed_help() {
    echo
    echo "Не удалось загрузить некоторые шрифты из интернета."
    echo "Возможные причины:"
    echo "1. Проблемы с интернет-соединением."
    echo "2. URL-адреса шрифтов устарели или недоступны."
    echo "3. Временная недоступность серверов."

    echo
    echo "Шрифты, которые не удалось обработать:"
    for font_info in "${fonts[@]}"; do
        IFS='|' read -r _ _ foldername <<< "$font_info"
        if [ ! -d "$DEST/$foldername" ] || [ "$(find "$DEST/$foldername" -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.otf" \) | wc -l)" -eq 0 ]; then
            echo "  - $foldername"
        fi
    done

    echo
    echo "Рекомендации:"
    echo "- Проверьте подключение к интернету (например, выполните: ping github.com)."
    echo "- Откройте URL проблемных шрифтов в браузере и убедитесь, что они доступны."
    echo "- При необходимости обновите URL в этом скрипте."
    echo "- Либо используйте локальные архивы (см. инструкцию выше)."
}

# Очистка папки шрифта: оставить только файлы .ttf и .otf в корне
folder_cleanup() {
    local folder="$1"
    if [ ! -d "$folder" ]; then
        return
    fi

    echo "Очистка папки '$folder': оставляем только файлы шрифтов (.ttf, .otf)..."

    local temp_dir=$(mktemp -d)
    find "$folder" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp {} "$temp_dir/" \; 2>/dev/null
    rm -rf "${folder:?}"/*
    cp "$temp_dir"/* "$folder/" 2>/dev/null || true
    rm -rf "$temp_dir"

    local count=$(find "$folder" -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.otf" \) | wc -l)
    echo "В папке '$folder' осталось $count файлов шрифтов."
}

# Создание локального архива из обработанной папки шрифта
create_offline_archive() {
    local folder="$1"
    local archive_name="$2"
    local archive_path="$SCRIPT_DIR/$archive_name"

    if [ ! -d "$folder" ]; then
        return
    fi

    echo "Создание архива для автономной работы: $archive_name"

    if find "$folder" -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.otf" \) | read -r; then
        (cd "$folder" && zip -qr "$archive_path" . -i "*.ttf" "*.otf" "*.TTF" "*.OTF")
        echo "Архив '$archive_name' успешно создан."
    else
        echo "Нет файлов шрифтов для архивации в папке '$(basename "$folder")'."
    fi
}

# Установка шрифтов в пользовательскую директорию
install_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    local installed_count=0

    echo "Установка шрифтов в систему..."
    mkdir -p "$font_dir"

    while IFS= read -r -d '' font_file; do
        if cp "$font_file" "$font_dir/"; then
            ((installed_count++))
        fi
    done < <(find "$DEST" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print0)

    echo "Обновление кэша шрифтов..."
    if fc-cache -fv >/dev/null 2>&1; then
        echo "Кэш шрифтов успешно обновлён."
    else
        echo "Внимание: не удалось обновить кэш шрифтов. Шрифты могут не отображаться до перезагрузки."
    fi

    echo "Установлено $installed_count шрифтов."
    return $installed_count
}

# Проверка наличия установленных шрифтов
check_installed_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    if [ -d "$font_dir" ]; then
        local count=$(find "$font_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \) 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            echo "В системе обнаружено $count установленных шрифтов."
            return 0
        fi
    fi
    echo "Шрифты не найдены в директории '$font_dir'."
    return 1
}

# Основная функция: загрузка и обработка одного шрифта
download_and_process_font() {
    local url="$1"
    local filename="$2"
    local foldername="$3"
    local archive_path="$SCRIPT_DIR/$filename"
    local folderpath="$DEST/$foldername"

    echo "Обработка шрифта: $foldername"

    # 1. Проверка наличия валидного локального архива
    if [ -f "$archive_path" ] && unzip -tq "$archive_path" >/dev/null 2>&1; then
        echo "Найден локальный архив: $filename. Распаковка..."
        rm -rf "$folderpath"
        mkdir -p "$folderpath"
        if ! unzip -q -o "$archive_path" -d "$folderpath"; then
            echo "Ошибка: архив '$filename' повреждён."
            return 1
        fi
        echo "Шрифт '$foldername' успешно обработан из локального архива."
        return 0
    fi

    # 2. Если архива нет, требуется интернет
    if [ "$HAS_INTERNET" != "true" ]; then
        echo "Архив '$filename' отсутствует, и интернет недоступен. Пропускаем шрифт '$foldername'."
        return 1
    fi

    # 3. Скачивание архива во временную директорию
    local temp_dir=$(mktemp -d)
    local temp_file="$temp_dir/$filename"
    echo "Скачивание архива из интернета (макс. 3 попытки, таймаут 60 сек)..."

    if ! wget --timeout=60 --continue --tries=3 --no-check-certificate -q --show-progress -O "$temp_file" "$url"; then
        echo "Не удалось скачать шрифт '$foldername'. Пропускаем."
        rm -rf "$temp_dir"
        return 1
    fi

    # 4. Распаковка
    rm -rf "$folderpath"
    mkdir -p "$folderpath"
    if ! unzip -q -o "$temp_file" -d "$folderpath"; then
        echo "Не удалось распаковать архив для '$foldername'. Пропускаем."
        rm -rf "$temp_dir"
        return 1
    fi

    # 5. Очистка и создание локального архива для будущего использования
    folder_cleanup "$folderpath"
    create_offline_archive "$folderpath" "$filename"

    rm -rf "$temp_dir"
    echo "Шрифт '$foldername' успешно загружен и обработан."
    return 0
}

# Удаление временной папки fonts после установки
cleanup_fonts_folder() {
    echo "Удаление временной папки '$DEST'..."
    if [ -d "$DEST" ]; then
        rm -rf "$DEST"
        echo "Временная папка удалена."
    fi
}

# === ОСНОВНОЙ БЛОК СКРИПТА ===

# 1. Проверка зависимостей
check_dependencies

# 2. Проверка интернета
HAS_INTERNET=$(check_internet)
if [ "$HAS_INTERNET" = "true" ]; then
    echo "Интернет-соединение доступно."
else
    echo "Интернет-соединение недоступно."
fi

# 3. Проверка локальных архивов
EXISTING_ARCHIVES=$(check_existing_archives)

# 4. Проверка возможности работы
if [ "$HAS_INTERNET" = "false" ] && [ "$EXISTING_ARCHIVES" -eq 0 ]; then
    echo "Ошибка: отсутствует интернет и локальные архивы шрифтов."
    show_local_archive_help
    exit 1
fi

if [ "$HAS_INTERNET" = "false" ]; then
    echo "Работа в автономном режиме."
fi

# 5. Обработка каждого шрифта
success_count=0
for font_info in "${fonts[@]}"; do
    IFS='|' read -r url filename foldername <<< "$font_info"
    echo "=== Обработка: $foldername ==="
    if download_and_process_font "$url" "$filename" "$foldername"; then
        ((success_count++))
    fi
    echo
done

# 6. Итоговая статистика
echo "Обработка завершена. Успешно обработано: $success_count из ${#fonts[@]} шрифтов."

total_fonts=0
echo "Статистика по шрифтам:"
for folder in "$DEST"/*/; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")
        count=$(find "$folder" -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.otf" \) | wc -l)
        if [ $count -gt 0 ]; then
            echo "  - $folder_name: $count шрифтов"
            total_fonts=$((total_fonts + count))
        else
            echo "  - $folder_name: файлы шрифтов не найдены"
        fi
    fi
done
echo "Всего готово к установке: $total_fonts шрифтов."

# 7. Обработка ошибок
if [ "$total_fonts" -eq 0 ]; then
    echo "Не удалось получить ни одного шрифта."
    if [ "$HAS_INTERNET" = "true" ]; then
        show_download_failed_help
    else
        show_local_archive_help
    fi
    exit 1
fi

# 8. Установка шрифтов
echo "Все шрифты готовы к установке."
read -p "Установить шрифты в систему? (Y/n): " -n 1 -r install_choice
echo

if [[ $install_choice =~ ^[Yy]$ ]]; then
    install_fonts
    cleanup_fonts_folder
    check_installed_fonts
    echo "Установка шрифтов завершена."
else
    echo "Установка отменена."
    echo "Вы можете запустить скрипт повторно — локальные архивы уже сохранены, и установка пройдёт быстро."
fi

# Конец скрипта
