# =============================================================================
# mybash-tools / aliases
# Версия: 1.2
# Назначение: Удобные алиасы для повседневных команд.
# Авторство: Lincooln с активным участием Qwen3-Max
# Зависимости: Использует переменные из mybashrc.sh (EDITOR, MYBASH_UPDATE_CMD)
# Репозиторий: https://github.com/lincooln/mybash-tools
# Комментарии:
#   - Все алиасы простые и понятные.
#   - Для продвинутых сценариев см. закомментированные примеры ниже.
# =============================================================================

# @cmd e — открыть редактор
alias e="$EDITOR"

# @cmd fm — файловый менеджер (требуется mc)
alias fm="mc"

# @cmd t — мониторинг процессов (требуется htop)
alias t="htop"

# @cmd update — обновить систему
alias update="$MYBASH_UPDATE_CMD"

# @cmd ls — показать все файлы с цветом
alias ls='ls -a --color=auto'

# @cmd ps — дерево процессов
alias ps='ps auxf'

# @cmd ping — 10 пакетов по умолчанию
alias ping='ping -c 10'

# @cmd less — просмотр с поддержкой цвета
alias less='less -R'

# @cmd cp — безопасное копирование
alias cp='cp -i'

# @cmd mv — безопасное перемещение
alias mv='mv -i'

# @cmd mkdir — создание директорий с родителями
alias mkdir='mkdir -p'

# === МЕЖСИСТЕМНЫЕ ПРИВЫЧКИ ===
# На ALT Linux и Debian-подобных системах apt → apt-get
if [[ "$MYBASH_DISTRO" == "altlinux" || "$MYBASH_DISTRO" == "alt" || "$MYBASH_DISTRO" == "basealt" || "$MYBASH_DISTRO" == "debian" || "$MYBASH_DISTRO" == "ubuntu" || "$MYBASH_DISTRO" == "linuxmint" ]]; then
    # @cmd apt — пакетный менеджер (на ALT Linux → apt-get)
    alias apt="apt-get"
fi

# Alias's for archives
# alias mktar='tar -cvf'
# alias mkbz2='tar -cvjf'
# alias mkgz='tar -cvzf'
# alias untar='tar -xvf'
# alias unbz2='tar -xvjf'
# alias ungz='tar -xvzf'

# === ПАСХАЛКИ ===
# @cmd secret — пасхалка разработчика
alias secret='echo "Разработал Lincooln, реализовал Qwen3-Max — и да, мы оба любим хороший bash-код."'

# @cmd oops — список исправлений опечаток
alias oops='echo "Доступные исправления: sl→ls, cls→clear, gerp→grep, mkae→make, apt↔apt-get (авто-подсказка)"'

# === ПРИМЕРЫ ДЛЯ ПРОДВИНУТЫХ (раскомментируйте при необходимости) ===
# Безопасный алиас для mc с fallback на ls:
# fm() {
#     if command -v mc >/dev/null 2>&1; then
#         command mc "$@"
#     else
#         echo "⚠️  mc не установлен. Использую альтернативу: ls" >&2
#         ls "$@"
#     fi
# }
