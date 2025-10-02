# =============================================================================
# mybash-tools / functions
# Версия: 1.2
# Назначение: Полезные пользовательские функции.
# Авторство: Lincooln с активным участием Qwen3-Max
# Зависимости: Использует MYBASH_INSTALL_CMD из профиля ОС.
# Репозиторий: https://github.com/lincooln/mybash-tools
# =============================================================================

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
    echo "Shell: $SHELL"
    echo "User: $USER"
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


# docker-clean=' \
#   docker container prune -f ; \
#   docker image prune -f ; \
#   docker network prune -f ; \
#   docker volume prune -f '

# # цвета для вывода man цветным
# export LESS_TERMCAP_mb=$'\E[01;31m'
# export LESS_TERMCAP_md=$'\E[01;31m'
# export LESS_TERMCAP_me=$'\E[0m'
# export LESS_TERMCAP_se=$'\E[0m'
# export LESS_TERMCAP_so=$'\E[01;44;33m'
# export LESS_TERMCAP_ue=$'\E[0m'
# export LESS_TERMCAP_us=$'\E[01;32m'
