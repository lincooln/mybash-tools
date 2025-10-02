# =============================================================================
# mybash-tools / completion
# Версия: 1.0
# Назначение: Минимальное автодополнение для команд mybash-tools.
# Авторство: Lincooln с активным участием Qwen3-Max
# Зависимости: bash-completion (опционально), стандартные утилиты.
# Репозиторий: https://github.com/lincooln/mybash-tools
# Комментарии:
#   - Работает даже без системного bash-completion.
#   - Дополняет только команды из mybash-tools.
# =============================================================================

# @cmd completion — настройка автодополнения

# Проверяем, загружен ли bash-completion
if ! type _completion_loader >/dev/null 2>&1; then
    # Минимальная реализация автодополнения для наших команд
    _mybash_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local cmd="${COMP_WORDS[0]}"

        case "$cmd" in
            fm)
                # Дополнение для файлового менеджера (пути)
                COMPREPLY=( $(compgen -d -- "$cur") )
                ;;
            t)
                # htop не требует аргументов
                COMPREPLY=()
                ;;
            update)
                # update не требует аргументов
                COMPREPLY=()
                ;;
            mycmd)
                # Дополнение для mycmd: список команд
                COMPREPLY=( $(compgen -W "$(mycmd 2>/dev/null | grep -o '^[a-z-][a-z0-9-]*')" -- "$cur") )
                ;;
            extract)
                # Дополнение для extract: файлы архивов
                COMPREPLY=( $(compgen -f -X '!*.@(tar.bz2|tar.gz|bz2|gz|tar|tbz2|tgz|zip|Z|7z)' -- "$cur") )
                ;;
            mkcd)
                # Дополнение для mkcd: существующие директории
                COMPREPLY=( $(compgen -d -- "$cur") )
                ;;
            *)
                # Для остальных — стандартное поведение
                COMPREPLY=()
                ;;
        esac
    }

    # Регистрируем автодополнение для наших команд
    complete -F _mybash_completion fm t update mycmd extract mkcd
else
    # Если bash-completion доступен — используем его
    # (наши команды могут быть дополнены через /etc/bash_completion.d/)
    :
fi
