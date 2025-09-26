#!/usr/bin/env bash

# =============================================================================
# MYBASHRC — инсталлятор персонального bash-фреймворка
# Версия: 1.4 (с --dry-run, пасхалками и исправлением опечаток)
#
# Разработал Lincooln, реализовал в коде Qwen3-Max
# =============================================================================

_MYBASH_TARGET="$HOME/.mybashrc"
_dry_run=false

# === СПИСКИ УТИЛИТ ===========================================================
declare -A _ALL_TOOLS_GROUPS
_ALL_TOOLS_GROUPS["base"]="Базовые утилиты|nano htop"
_ALL_TOOLS_GROUPS["network"]="Сетевые инструменты|git curl wget"

declare -A _DEBIAN_TOOLS_GROUPS
_DEBIAN_TOOLS_GROUPS["mc"]="Midnight Commander|mc"

declare -A _ALT_TOOLS_GROUPS
_ALT_TOOLS_GROUPS["eepm"]="EterSoft PM|eepm"
_ALT_TOOLS_GROUPS["alterator"]="Alterator|alterator alterator-tool alterator-base"

declare -A _REDOS_TOOLS_GROUPS
# _REDOS_TOOLS_GROUPS["..."]="..."

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ================================================

_my_is_installed() {
    local pkg="$1"
    case "$_myos" in
        debian)
            dpkg -l "$pkg" &>/dev/null
            ;;
        altlinux|redos)
            rpm -q "$pkg" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

_my_install_packages() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then return 0; fi
    if $_dry_run; then
        echo "[DRY-RUN] Установка пакетов: ${packages[*]}"
        return 0
    fi
    case "$_myos" in
        debian)
            sudo apt install -y "${packages[@]}" || { echo "❌ Ошибка установки в Debian"; return 1; }
            ;;
        altlinux|redos)
            sudo apt-get install -y "${packages[@]}" || { echo "❌ Ошибка установки в $_myos"; return 1; }
            ;;
        *)
            echo "Установка не поддерживается для $_myos"
            return 1
            ;;
    esac
}

_my_remove_packages() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then return 0; fi
    if $_dry_run; then
        echo "[DRY-RUN] Удаление пакетов: ${packages[*]}"
        return 0
    fi
    case "$_myos" in
        debian)
            sudo apt remove -y "${packages[@]}" || { echo "❌ Ошибка удаления в Debian"; return 1; }
            ;;
        altlinux|redos)
            sudo apt-get remove -y "${packages[@]}" || { echo "❌ Ошибка удаления в $_myos"; return 1; }
            ;;
        *)
            echo "Удаление не поддерживается для $_myos"
            return 1
            ;;
    esac
}

_my_setup_tool() {
    declare -A _MY_TOOLS_MERGED
    for tag in "${!_ALL_TOOLS_GROUPS[@]}"; do
        _MY_TOOLS_MERGED["$tag"]="${_ALL_TOOLS_GROUPS[$tag]}"
    done
    case "$_myos" in
        debian)
            for tag in "${!_DEBIAN_TOOLS_GROUPS[@]}"; do
                _MY_TOOLS_MERGED["$tag"]="${_DEBIAN_TOOLS_GROUPS[$tag]}"
            done
            ;;
        altlinux)
            for tag in "${!_ALT_TOOLS_GROUPS[@]}"; do
                _MY_TOOLS_MERGED["$tag"]="${_ALT_TOOLS_GROUPS[$tag]}"
            done
            ;;
        redos)
            for tag in "${!_REDOS_TOOLS_GROUPS[@]}"; do
                _MY_TOOLS_MERGED["$tag"]="${_REDOS_TOOLS_GROUPS[$tag]}"
            done
            ;;
    esac

    if ! command -v dialog >/dev/null; then
        echo "Устанавливаю dialog для интерактивного выбора..."
        case "$_myos" in
            debian) sudo apt install -y dialog ;;
            altlinux|redos) sudo apt-get install -y dialog ;;
        esac
    fi

    local dialog_args=()
    for tag in "${!_MY_TOOLS_MERGED[@]}"; do
        IFS='|' read -r display_name packages_str <<< "${_MY_TOOLS_MERGED[$tag]}"
        read -ra packages <<< "$packages_str"

        local all_installed=true
        for pkg in "${packages[@]}"; do
            if ! _my_is_installed "$pkg"; then
                all_installed=false
                break
            fi
        done
        local state=$( [[ "$all_installed" == true ]] && echo "on" || echo "off" )
        dialog_args+=("$tag" "$display_name" "$state")
    done

    local selected_tags
    selected_tags=$(dialog --stdout --checklist "Выберите утилиты:" 20 70 10 "${dialog_args[@]}")
    [[ $? -ne 0 ]] || [[ -z "$selected_tags" ]] && { echo "Отмена установки."; return 0; }

    local to_install=() to_remove=()
    for tag in "${!_MY_TOOLS_MERGED[@]}"; do
        IFS='|' read -r _ packages_str <<< "${_MY_TOOLS_MERGED[$tag]}"
        read -ra packages <<< "$packages_str"

        if [[ " $selected_tags " == *" $tag "* ]]; then
            for pkg in "${packages[@]}"; do
                if ! _my_is_installed "$pkg"; then
                    to_install+=("$pkg")
                fi
            done
        else
            for pkg in "${packages[@]}"; do
                if _my_is_installed "$pkg"; then
                    to_remove+=("$pkg")
                fi
            done
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        if $_dry_run; then
            echo "[DRY-RUN] Будут установлены: ${to_install[*]}"
        else
            echo "Устанавливаю: ${to_install[*]}"
        fi
        _my_install_packages "${to_install[@]}" || return 1
    fi
    if [[ ${#to_remove[@]} -gt 0 ]]; then
        if $_dry_run; then
            echo "[DRY-RUN] Будут удалены: ${to_remove[*]}"
        else
            echo "Удаляю: ${to_remove[*]}"
        fi
        _my_remove_packages "${to_remove[@]}" || return 1
    fi
}

# === ОСНОВНАЯ ЛОГИКА ==========================================================

_myos="unknown"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID_LIKE:-$ID}" in
        *debian*)
            _myos="debian"
            ;;
        *altlinux*)
            _myos="altlinux"
            ;;
        redos)
            _myos="redos"
            ;;
        *)
            _myos="$ID"
            ;;
    esac
fi

# Обработка аргументов
_action=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            _dry_run=true
            shift
            ;;
        -i|--install|-u|--uninstall)
            _action="$1"
            shift
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
done

case "${_action:-}" in
    -i|--install)
        if command -v sudo >/dev/null 2>&1; then
            echo "🔑 Обнаружен sudo. Проверка прав..."
            if sudo -n true 2>/dev/null; then
                echo "✅ Доступ без пароля. Запускаю установку утилит..."
                _my_setup_tool
            else
                echo "🔒 sudo требует пароль. Попытка получить права..."
                if sudo true 2>/dev/null; then
                    echo "✅ Пароль принят. Запускаю установку утилит..."
                    _my_setup_tool
                else
                    echo "❌ sudo недоступен. Пропускаю установку утилит."
                fi
            fi
        else
            echo "ℹ️ sudo не найден. Пропускаю установку утилит."
        fi

        # === Определяем инструменты (без изменений) ===
        _my_editor=""
        if [[ -n "$EDITOR" ]] && command -v "$EDITOR" >/dev/null 2>&1; then
            _my_editor="$EDITOR"
        elif command -v mcedit >/dev/null 2>&1; then
            _my_editor="mcedit"
        elif command -v nano >/dev/null 2>&1; then
            _my_editor="nano"
        elif command -v vi >/dev/null 2>&1; then
            _my_editor="vi"
        else
            _my_editor="cat"
        fi

        _my_fm=""
        if command -v mc >/dev/null 2>&1; then
            _my_fm="mc"
        fi

        _my_top="top"
        if command -v htop >/dev/null 2>&1; then
            _my_top="htop"
        fi

        # === Оформление (без изменений) ===
        _MYBASH_USE_ICONS=1
        if [[ -n "$COLORTERM" ]] || [[ "$TERM" == *"256color"* ]] || [[ "$TERM" == "xterm"* ]]; then
            _MYBASH_COLOR_MODE="color"
        else
            _MYBASH_COLOR_MODE="tty"
        fi

        if [[ "$_MYBASH_COLOR_MODE" == "color" ]] && [[ "${_MYBASH_USE_ICONS:-}" == "1" ]]; then
            _MYBASH_TIME_ICON=" "
            _MYBASH_HOST_ICON=" "
            _MYBASH_DIR_ICON=" "
            _MYBASH_PROMPT_ICON=" "
        elif [[ "$_MYBASH_COLOR_MODE" == "color" ]]; then
            _MYBASH_TIME_ICON=""
            _MYBASH_HOST_ICON=""
            _MYBASH_DIR_ICON=""
            _MYBASH_PROMPT_ICON="→ "
        else
            _MYBASH_TIME_ICON=""
            _MYBASH_HOST_ICON=""
            _MYBASH_DIR_ICON=""
            _MYBASH_PROMPT_ICON="> "
        fi

        if [[ "$_MYBASH_COLOR_MODE" == "color" ]]; then
            _MYBASH_TIME_COLOR="\[\e[90m\]"
            _MYBASH_HOST_COLOR="\[\e[36m\]"
            _MYBASH_PATH_COLOR="\[\e[37m\]"
            _MYBASH_PROMPT_COLOR="\[\e[35m\]"
            _MYBASH_RESET="\[\e[0m\]"
        else
            _MYBASH_TIME_COLOR=""
            _MYBASH_HOST_COLOR=""
            _MYBASH_PATH_COLOR=""
            _MYBASH_PROMPT_COLOR=""
            _MYBASH_RESET=""
        fi

        # === Генерация ~/.mybashrc (теперь с пасхалками и исправлениями!) ===
        if $_dry_run; then
            echo "[DRY-RUN] Будет создан файл: $_MYBASH_TARGET"
            echo "[DRY-RUN] Будет добавлена запись в ~/.bashrc"
        else
            cat > "$_MYBASH_TARGET" <<EOF
# ~/.mybashrc — сгенерировано автоматически

# === СИСТЕМА ===
_myos="$_myos"

# === ИНСТРУМЕНТЫ ===
_my_editor="$_my_editor"
_my_fm="$_my_fm"
_my_top="$_my_top"

# === ОФОРМЛЕНИЕ ===
_MYBASH_USE_ICONS=$_MYBASH_USE_ICONS
_MYBASH_COLOR_MODE="$_MYBASH_COLOR_MODE"
_MYBASH_TIME_ICON="$_MYBASH_TIME_ICON"
_MYBASH_HOST_ICON="$_MYBASH_HOST_ICON"
_MYBASH_DIR_ICON="$_MYBASH_DIR_ICON"
_MYBASH_PROMPT_ICON="$_MYBASH_PROMPT_ICON"
_MYBASH_TIME_COLOR="$_MYBASH_TIME_COLOR"
_MYBASH_HOST_COLOR="$_MYBASH_HOST_COLOR"
_MYBASH_PATH_COLOR="$_MYBASH_PATH_COLOR"
_MYBASH_PROMPT_COLOR="$_MYBASH_PROMPT_COLOR"
_MYBASH_RESET="$_MYBASH_RESET"

# === ПРИГЛАШЕНИЕ ===
PS1="\${_MYBASH_TIME_COLOR}\${_MYBASH_TIME_ICON}\D{%Y-%m-%d %H:%M:%S}\${_MYBASH_RESET} \${_MYBASH_HOST_COLOR}\${_MYBASH_HOST_ICON}[\h-\u]\${_MYBASH_RESET} \${_MYBASH_PATH_COLOR}\${_MYBASH_DIR_ICON}\w\${_MYBASH_RESET}\n\${_MYBASH_PROMPT_COLOR}\${_MYBASH_PROMPT_ICON}\${_MYBASH_RESET}"

# === АЛИАСЫ ===
# @cmd e — редактор ($_my_editor)
alias e="$_my_editor"

# @cmd mc — файловый менеджер или список файлов
$(if [[ -n "$_my_fm" ]]; then
    echo "alias mc=\"$_my_fm\""
else
    echo "alias mc='echo \"mc не установлен, используй e или ls\" >&2 && ls -a'"
fi)

# @cmd t — мониторинг процессов ($_my_top)
alias t="$_my_top"

# @cmd ls — все файлы (включая скрытые)
alias ls='ls -a'

# @cmd update — обновить систему
$(case "$_myos" in
    debian) echo "alias update='sudo apt update && sudo apt upgrade -y'" ;;
    altlinux|redos) echo "alias update='sudo apt-get update && sudo apt-get upgrade -y'" ;;
    *) echo "alias update='echo \"ОС не поддерживается: $_myos\"'" ;;
esac)

# === ПАСХАЛКИ ===
# @cmd secret — личное приветствие от авторов
alias secret='echo "Разработал Lincooln, реализовал Qwen3-Max — и да, мы оба любим хороший bash-код."'

# @cmd oops — показать все исправления опечаток
alias oops='echo "Доступные исправления: sl→ls, cls→clear, gerp→grep, mkae→make, apt↔apt-get (авто-подсказка)"'

# Исправления опечаток (всегда включены)
sl() {
    echo -e "\\n🚂 Ой! Ты, наверное, хотел написать \\\`ls\\\`?\\n"
    sleep 2
    command ls "\$@"
}

cls() {
    echo -e "\\n🧹 Ой! В Linux команда — \\\`clear\\\`. Сейчас всё почищу!\\n"
    sleep 2
    command clear
}

gerp() {
    echo -e "\\n🔍 Ой! Похоже, ты искал \\\`grep\\\`? Ищу за тебя...\\n"
    sleep 2
    command grep "\$@"
}

grpe() {
    echo -e "\\n🔍 Ой! Возможно, ты имел в виду \\\`grep\\\`?\\n"
    sleep 2
    command grep "\$@"
}

mkae() {
    echo -e "\\n⚙️ Ой! Команда сборки — \\\`make\\\`. Запускаю...\\n"
    sleep 2
    command make "\$@"
}

mak() {
    echo -e "\\n⚙️ Ой! Ты, скорее всего, хотел \\\`make\\\`?\\n"
    sleep 2
    command make "\$@"
}

# Авто-исправление apt/apt-get — только для нужного дистрибутива
$(case "$_myos" in
    altlinux|redos)
        cat <<'SUBEOF'
apt() {
    echo -e "\n📦 Ой! В $_myos пакетный менеджер — \`apt-get\`. Сейчас выполню через него...\n"
    sleep 2
    command apt-get "$@"
}
SUBEOF
        ;;
    debian)
        cat <<'SUBEOF'
apt-get() {
    echo -e "\n📦 Ой! В современных Debian-системах удобнее использовать \`apt\`. Но сделаю, как просишь...\n"
    sleep 2
    command apt-get "$@"
}
SUBEOF
        ;;
esac)

# === ФУНКЦИИ ===
# @cmd info — ОС и ядро
info() {
    echo "=== System Info ==="
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "OS: \$PRETTY_NAME"
    else
        echo "OS: \$OSTYPE"
    fi
    echo "Kernel: \$(uname -sr)"
    # Пасхалка только для владельца
    if [[ "\$USER" == "$(printf '%q' "$USER")" ]]; then
        echo -e "\n💡 P.S. Этот фреймворк создан с заботой. Ошибки — часть пути. Главное — не бояться их исправлять.\n"
    fi
}

# @cmd extract — распаковать архив
extract() {
    if [[ -f "\$1" ]]; then
        case "\$1" in
            *.tar.bz2)   tar xjf "\$1" ;;
            *.tar.gz)    tar xzf "\$1" ;;
            *.bz2)       bunzip2 "\$1" ;;
            *.gz)        gunzip "\$1" ;;
            *.tar)       tar xf "\$1" ;;
            *.tbz2)      tar xjf "\$1" ;;
            *.tgz)       tar xzf "\$1" ;;
            *.zip)       unzip "\$1" ;;
            *.Z)         uncompress "\$1" ;;
            *.7z)        7z x "\$1" ;;
            *)           echo "'\$1' — неизвестный формат" ;;
        esac
    else
        echo "'\$1' — файл не найден"
    fi
}

# @cmd mycmd — показать все доступные команды
mycmd() {
    echo "Доступные команды из ~/.mybashrc:"
    echo "----------------------------------"
    grep -h "^# @cmd" "$_MYBASH_TARGET" 2>/dev/null | \\
        sed 's/^# @cmd[[:space:]]*//' | \\
        sort
}

# === АВТОДОПОЛНЕНИЯ ===
# @cmd systemctl — автодополнение для systemd
$(if command -v systemctl >/dev/null 2>&1; then
    echo "source /usr/share/bash-completion/completions/systemctl 2>/dev/null || \\"
    echo "complete -W \"start stop restart status enable disable list-units list-unit-files\" systemctl"
else
    echo "# systemctl недоступен — автодополнение отключено"
fi)
EOF

            # Подключаем к ~/.bashrc
            if ! grep -q "# MYBASH INIT" "$HOME/.bashrc" 2>/dev/null; then
                echo -e "\n# MYBASH INIT\nsource $_MYBASH_TARGET" >> "$HOME/.bashrc"
                echo "✅ mybash подключён к ~/.bashrc"
            fi
            echo "✅ mybash установлен в $_MYBASH_TARGET"
            echo "👉 Выполни: source ~/.bashrc"
        fi
        ;;

    -u|--uninstall)
        if $_dry_run; then
            echo "[DRY-RUN] Будет удалён файл: $_MYBASH_TARGET"
            echo "[DRY-RUN] Будет удалена запись из ~/.bashrc"
        else
            if [[ -f "$HOME/.bashrc" ]]; then
                sed -i.bak '/# MYBASH INIT/,+1d' "$HOME/.bashrc" 2>/dev/null || true
                echo "🧹 Запись из ~/.bashrc удалена (резерв: ~/.bashrc.bak)"
            fi
            rm -f "$_MYBASH_TARGET"
            echo "🗑️ mybash удалён."
        fi
        ;;

    "")
        cat <<'EOF'
MYBASHRC — инсталлятор персонального bash-фреймворка

Использование:
  ./mybashrc.sh -i [--dry-run]     → установить
  ./mybashrc.sh -u [--dry-run]     → удалить
  ./mybashrc.sh                    → эта справка

Опции:
  -n, --dry-run   → показать, что будет сделано, без реальных изменений
EOF
        ;;

    *)
        echo "Неизвестное действие: $_action"
        exit 1
        ;;
esac
