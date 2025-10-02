# =============================================================================
# mybash-tools / prompt
# Версия: 1.2
# Назначение: Настройка цветного приглашения командной строки (PS1) с иконками.
# Авторство: Lincooln с активным участием Qwen3-Max
# Зависимости: Использует переменные из mybashrc.sh (_MYBASH_USE_ICONS и др.)
# Репозиторий: https://github.com/lincooln/mybash-tools
# =============================================================================

# Защита от повторного подключения
if [[ -n "${_MYBASH_PROMPT_LOADED:-}" ]]; then
    return 0
fi
_MYBASH_PROMPT_LOADED=1

# Устанавливаем значения по умолчанию, если не заданы извне
: ${_MYBASH_USE_ICONS:=1}
: ${_MYBASH_COLOR_MODE:="color"}

# Иконки или текстовые метки
if [[ $_MYBASH_USE_ICONS -eq 1 ]]; then
    _MYBASH_TIME_ICON=" "
    _MYBASH_HOST_ICON=" "
    _MYBASH_DIR_ICON=" "
    _MYBASH_PROMPT_ICON=" "
else
    _MYBASH_TIME_ICON="[TIME] "
    _MYBASH_HOST_ICON="[HOST] "
    _MYBASH_DIR_ICON="[DIR] "
    _MYBASH_PROMPT_ICON="> "
fi

# Цвета
if [[ "$_MYBASH_COLOR_MODE" == "color" ]]; then
    _MYBASH_TIME_COLOR="\[\e[90m\]"
    _MYBASH_PATH_COLOR="\[\e[37m\]"
    _MYBASH_PROMPT_COLOR="\[\e[35m\]"
    _MYBASH_RESET="\[\e[0m\]"

    if [[ $EUID -eq 0 ]]; then
        _MYBASH_HOST_COLOR="\[\e[31m\]"   # root — красный
        _MYBASH_USER_HOST="root@\h"
    else
        _MYBASH_HOST_COLOR="\[\e[36m\]"   # обычный — голубой
        _MYBASH_USER_HOST="\u@\h"
    fi
else
    _MYBASH_TIME_COLOR=""
    _MYBASH_HOST_COLOR=""
    _MYBASH_PATH_COLOR=""
    _MYBASH_PROMPT_COLOR=""
    _MYBASH_RESET=""
    _MYBASH_USER_HOST="\u@\h"
fi

# Функция для установки PS1
_mybash_set_prompt() {
    PS1="${_MYBASH_TIME_COLOR}${_MYBASH_TIME_ICON}\D{%Y-%m-%d %H:%M:%S}${_MYBASH_RESET} ${_MYBASH_HOST_COLOR}${_MYBASH_HOST_ICON}[${_MYBASH_USER_HOST}]${_MYBASH_RESET} ${_MYBASH_PATH_COLOR}${_MYBASH_DIR_ICON}\w${_MYBASH_RESET}
${_MYBASH_ERROR_INDICATOR}${_MYBASH_PROMPT_COLOR}${_MYBASH_PROMPT_ICON}${_MYBASH_RESET}"
}

# Индикатор ошибки
_mybash_prompt_cmd() {
    if [[ $? -ne 0 ]]; then
        _MYBASH_ERROR_INDICATOR="❌ "
    else
        _MYBASH_ERROR_INDICATOR=""
    fi
    _mybash_set_prompt
}

# Устанавливаем PROMPT_COMMAND
PROMPT_COMMAND="_mybash_prompt_cmd"

# Справка по настройке PS1 (для редактирования):
# Доступные переменные:
#   \u — имя пользователя       \h — имя хоста
#   \w — текущая директория     \W — basename директории
#   \$ — "$" для пользователя, "#" для root
#   \D{...} — дата/время (см. strftime)
# Цвета: используйте \[\e[КОДm\] для цвета и \[\e[0m\] для сброса
# Иконки: замените _MYBASH_*_ICON в начале файла
# Чтобы отключить цвет/иконки — задайте в ~/.bashrc до подключения prompt:
#   export _MYBASH_USE_ICONS=0
#   export _MYBASH_COLOR_MODE="nocolor"
