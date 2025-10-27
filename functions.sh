# =============================================================================
# mybash-tools / functions
# Версия: 1.6
# Назначение: Полезные пользовательские функции.
# Авторство: Lincooln с активным участием Qwen3-Max
# Зависимости: Использует MYBASH_INSTALL_CMD из профиля ОС.
# Репозиторий: https://github.com/lincooln/mybash-tools
# =============================================================================

# Внутренняя функция: определение дистрибутива
_mybash_get_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release >/dev/null 2>&1; then
        lsb_release -i | awk '{print $3}' | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# @cmd info — информация о системе
info() {
    echo "=== System Info ==="
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "OS: $PRETTY_NAME"
    else
        echo "OS: $OSTYPE"
    fi
    echo "Kernel: $(uname -sr)"
    echo "Shell: $SHELL (версия: ${BASH_VERSION:-неизвестно})"
    echo "User: $USER"
}

# @cmd hostname — управление именем хоста (просмотр/изменение)
hostname() {
    local new_name="$1"

    # Без аргументов — показываем текущее имя
    if [[ -z "$new_name" ]]; then
        command hostname
        return 0
    fi

    # Проверка корректности имени
    if [[ ! "$new_name" =~ ^[a-zA-Z][a-zA-Z0-9\-]{0,62}$ ]] || [[ "$new_name" == *- ]]; then
        echo "❌ Некорректное имя хоста: '$new_name'"
        echo "   Требования:"
        echo "   - Должно начинаться с латинской буквы"
        echo "   - Может содержать буквы, цифры и дефис (-)"
        echo "   - Длина от 1 до 63 символов"
        echo "   - Не может заканчиваться дефисом"
        return 1
    fi

    # Универсальный метод для всех современных систем
    if command -v hostnamectl >/dev/null; then
        echo "$new_name" | sudo tee /etc/hostname >/dev/null
        sudo hostnamectl set-hostname "$new_name"
    else
        # Резерв для очень старых систем
        echo "$new_name" | sudo tee /etc/hostname >/dev/null
        sudo hostname "$new_name"
    fi

    echo "✅ Имя хоста изменено на: $new_name"

    # Обновляем приглашение
    if command -v _mybash_set_prompt >/dev/null; then
        _mybash_set_prompt
        echo "ℹ️  Приглашение обновлено в текущей сессии."
    fi

    echo "ℹ️  Для полного применения перезагрузите систему или выполните:"
    echo "   sudo systemctl restart systemd-hostnamed"
}

# @cmd pkg+ — установить пакет (без рекомендованных зависимостей)
pkg+() {
    if [[ $# -eq 0 ]]; then
        echo "Использование: pkg+ <пакет> [пакет...]"
        return 1
    fi
    eval "$MYBASH_INSTALL_CMD" "$@"
}

# @cmd pkg++ — установить пакет (с рекомендованными зависимостями)
pkg++() {
    if [[ $# -eq 0 ]]; then
        echo "Использование: pkg++ <пакет> [пакет...]"
        return 1
    fi
    eval "$MYBASH_INSTALL_FULL_CMD" "$@"
}

# @cmd pkg- — удалить пакет (полностью, с настройками)
pkg-() {
    if [[ $# -eq 0 ]]; then
        echo "Использование: pkg- <пакет> [пакет...]"
        return 1
    fi
    eval "$MYBASH_REMOVE_CMD" "$@"
}

# @cmd fnd — поиск файлов и директорий по частичному совпадению
fnd() {
    local pattern="$1"
    local search_path="${2:-.}"

    if [[ -z "$pattern" ]]; then
        echo "Использование: fnd <шаблон> [путь]"
        echo "Примеры:"
        echo "  fnd доклад          # ищет 'доклад' в текущей папке"
        echo "  fnd доклад.jpg      # ищет файлы с расширением .jpg"
        echo "  fnd log /var        # ищет 'log' в /var"
        return 0
    fi

    if [[ ! -d "$search_path" ]]; then
        echo "❌ Путь не найден: $search_path"
        return 1
    fi

    # Проверяем наличие fd
    if command -v fd >/dev/null 2>&1; then
        echo "🔍 Использую быстрый поиск (fd)..."
        local ext=""
        if [[ "$pattern" == *.* ]]; then
            ext=".${pattern##*.}"
            pattern="${pattern%.*}"
        fi

        if [[ -n "$ext" ]]; then
            fd -t f -i "$pattern" -e "${ext#.}" "$search_path"
        else
            fd -t f -t d -i "$pattern" "$search_path"
        fi
    else
        echo "🔍 fd недоступен. Использую стандартный поиск (find)..."
        echo "   Совет: установите fd через 'pkg+ fd' для ускорения поиска"

        # Определяем расширение
        local ext=""
        if [[ "$pattern" == *.* ]]; then
            ext=".${pattern##*.}"
            pattern="${pattern%.*}"
        fi

        echo "🔍 Ищу '$pattern${ext}' в $search_path..."
        echo "   (Результаты появляются сразу. Нажмите Ctrl+C для отмены)"

        if [[ -n "$ext" ]]; then
            # Поиск файлов с расширением
            find "$search_path" -type f -iname "*${pattern}*${ext}" 2>/dev/null | \
            while IFS= read -r file; do
                printf "✅ %s\n" "$file"
            done
        else
            # Поиск файлов и папок по имени
            find "$search_path" \( -type f -o -type d \) -iname "*${pattern}*" 2>/dev/null | \
            while IFS= read -r item; do
                printf "✅ %s\n" "$item"
            done
        fi
    fi
}

# @cmd extract — универсальная распаковка архивов
extract() {
    if [[ ! -f "$1" ]]; then
        echo "❌ '$1' — файл не найден"
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2)
            if command -v tar >/dev/null; then
                tar xjf "$1"
            else
                echo "tar не установлен. Установите через: $MYBASH_INSTALL_CMD tar"
            fi ;;
        *.tar.gz|*.tgz)
            if command -v tar >/dev/null; then
                tar xzf "$1"
            else
                echo "tar не установлен. Установите через: $MYBASH_INSTALL_CMD tar"
            fi ;;
        *.bz2)
            if command -v bunzip2 >/dev/null; then
                bunzip2 "$1"
            else
                echo "bunzip2 не установлен. Установите через: $MYBASH_INSTALL_CMD bzip2"
            fi ;;
        *.gz)
            if command -v gunzip >/dev/null; then
                gunzip "$1"
            else
                echo "gzip не установлен. Установите через: $MYBASH_INSTALL_CMD gzip"
            fi ;;
        *.tar)
            if command -v tar >/dev/null; then
                tar xf "$1"
            else
                echo "tar не установлен. Установите через: $MYBASH_INSTALL_CMD tar"
            fi ;;
        *.zip)
            if command -v unzip >/dev/null; then
                unzip "$1"
            else
                echo "unzip не установлен. Установите через: $MYBASH_INSTALL_CMD unzip"
            fi ;;
        *.Z)
            if command -v uncompress >/dev/null; then
                uncompress "$1"
            else
                echo "compress не установлен. Установите через: $MYBASH_INSTALL_CMD compress"
            fi ;;
        *.7z)
            if command -v 7z >/dev/null; then
                7z x "$1"
            else
                echo "7z не установлен. Установите через: $MYBASH_INSTALL_CMD p7zip-full"
            fi ;;
        *)
            echo "❓ '$1' — неизвестный формат" ;;
    esac
}

# @cmd mycmd — показать все команды из mybash-tools
mycmd() {
    echo "Доступные команды из mybash-tools:"
    echo "----------------------------------"
    local mybash_dir="${MYBASH_DIR:-$HOME/.mybash}"
    if [[ -d "$mybash_dir" ]]; then
        grep -h "^# @cmd" "$mybash_dir"/* 2>/dev/null | sed 's/^# @cmd[[:space:]]*//' | sort -u
    else
        echo "Модули не найдены."
    fi
}

# @cmd mkcd — создать директорию и перейти в неё
mkcd() {
    if [[ -n "$1" ]]; then
        mkdir -p "$1" && cd "$1" || return 1
    else
        echo "Использование: mkcd <директория>"
        return 1
    fi
}
