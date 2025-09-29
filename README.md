mybash-tools
Наверное первый в мире проект, полностью написанный ИИ (Qwen3-Max) в соавторстве с человеком.
Человек — автор идеи, инициатор, тестировщик и вдохновитель.
ИИ — автор всего кода, архитектор и реализатор.

🎯 Цель проекта: создать лёгкое, переносимое, понятное и полностью рабочее окружение для терминала Linux, которое можно легко восстановить после переустановки системы.

💡 Философия: минимализм, прозрачность, автономность модулей, безопасность и обучение через практику.

👶 Для кого это: для новичков в Linux, которые хотят иметь удобный терминал, но не хотят разбираться в сложных фреймворках. Каждый файл — это учебник. 

📦 Что это?
mybash-tools — это набор самодостаточных bash-модулей, которые можно:

подключать все сразу через главный файл .mybashrc;
использовать по отдельности, подключая напрямую в свой .bashrc;
легко редактировать, расширять и переносить между машинами.
Проект не является фреймворком — он не пытается сделать всё за вас.
Он даёт только то, что реально используется, без избыточности.

🗂️ Структура проекта
```
mybash-tools/
├── install.sh                     # Установщик (клонирует, подключает к .bashrc)
├── mybashrc                       # Шаблон главного конфига
├── prompt.sh                      # Цветное приглашение с иконками
├── aliases.sh                     # Удобные алиасы (e, mc, t, update и др.)
├── typos.sh                       # Исправление опечаток (sl → ls, cls → clear и т.д.)
├── functions.sh                   # Полезные функции (info, extract, mycmd, alias_check)
├── completion.sh                  # Автодополнение (systemctl и др.)
├── help.sh                        # Персональная справочная система
├── nerdicons.sh                   # Поиск и управление иконками Nerd Fonts
├── tools/                         # Автономные утилиты-помощники
│   ├── install-fonts.sh           # Установка шрифтов (Nerd Fonts, Inter, PT Sans и др.)
│   └── install-syncthingtray.sh   # Установка SyncthingTray на ALT Linux
└── data/
    ├── help.txt                   # База знаний для `help`
    └── nerd-fonts.txt             # База иконок Nerd Fonts
```
📄 Описание файлов
🔧 install.sh
Установочный скрипт. Делает всё за вас:

клонирует репозиторий в ~/mybash;
создаёт ~/.mybashrc на основе шаблона;
подключает его к ~/.bashrc;
(опционально) предлагает установить базовые алиасы для root.
✅ Запускается один раз. Не влияет на производительность терминала. 

🧩 Модули (подключаются через ~/.mybashrc)

prompt.sh
Красивое приглашение с датой, хостом, путём и иконками (требуется Nerd Fonts).

aliases.sh
Алиасы для редактора (e), файлового менеджера (mc), мониторинга (t), обновления системы (update) и др.

typos.sh
Дружелюбные исправления опечаток:
sl, cls, gerp, mkae → правильные команды.

functions.sh
Полезные функции:
info (инфо о системе),
extract (распаковка архивов),
mycmd (список всех команд),
alias_check (проверка установленных программ).

completion.sh
Автодополнение для systemctl и других команд.

help.sh
Персональная справка:
help ls, help vi, help key → мгновенные подсказки.

nerdicons.sh
Поиск иконок:
icons git → покажет иконку, код и описание.

💡 Каждый модуль полностью автономен — можно подключить только help.sh, и он будет работать. 

🛠️ Утилиты (tools/)
Эти скрипты не подключаются через .bashrc — они запускаются вручную.

install-fonts.sh — установка любимых шрифтов. скачивает, очищает от мусора, устанавливает в систему, создаёт локальные архивы для offline-работы.

install-syncthingtray.sh — установка SyncthingTray на ALT Linux и производные с поддержкой резервных URL и проверкой зависимостей.

📚 Базы данных (data/)

help.txt — простой текстовый файл с подсказками. 
Формат: тема команда # пояснение
Пример: vi :q! # выйти без сохранения

nerd-fonts.txt — база иконок Nerd Fonts. 
Формат: U+XXXX;имя;тег1 тег2 ...
Пример: U+F09B;git;гит репозиторий

✏️ Оба файла можно редактировать через help edit и icons add. 

🚀 Установка
Установите Git (если ещё не установлен):
```bash
sudo apt install git
```
Склонируйте и установите:
```bash
git clone https://github.com/lincooln/mybash-tools.git ~/mybash
~/mybash/install.sh
```
Перезапустите терминал или выполните:
```bash
source ~/.bashrc
```
💡 При установке можно выбрать: подключать ли алиасы для root. 

♻️ Обновление
Просто выполните в папке проекта:

```bash
cd ~/mybash
git pull
```
Все изменения подхватятся автоматически.

🧪 Для тех, кто хочет продолжить развитие
Если вы хотите добавить новый модуль или утилиту:

Создайте файл в корне (модуль) или в tools/ (утилита).
Добавьте шапку с описанием и авторством.
Обязательно обновите этот README.md, добавив описание нового файла.
Не забудьте добавить ваш файл в ~/.mybashrc, если это модуль.

🔔 Важно для ИИ:
При генерации новых файлов всегда учитывайте, что этот проект — для новичков.
Следуйте лучшим практикам: 
понятные имена переменных (_my_editor, а не e);
безопасные дефолты (: ${var:=default});
проверка синтаксиса перед source;
документирование через # @cmd и help.txt.

🤝 Соавторство
Человек: Lincooln — идея, требования, тестирование, дизайн.
ИИ: Qwen3-Max — 100% кода, архитектура, документация, отладка.

🔐 Важно: При использовании или модификации этого проекта сохраняйте упоминание соавторства. 
Это не просто вежливость — это признание новой парадигмы: человек + ИИ = команда. 

📜 Лицензия
Проект распространяется «как есть», без гарантий.
Используйте на свой страх и риск.
Но если вам понравилось — поставьте ⭐️ на GitHub!

💬 «Я не изобретаю велосипед — я строю свой первый велосипед, чтобы понять, как он едет» — Lincooln 

<!-- AI-CTX:eyJwcm9qZWN0IjoibXliYXNoLXRvb2xzIiwiYXV0aG9yc2hpcCI6IkxpbmNvb2xuICsgUXdlbjMtTWF4IiwiZGVzY3JpcHRpb24iOiJGaXJzdCBlbmR0by1lbmQgY29sbGFib3JhdGl2ZSBwcm9qZWN0IGJldHdlZW4gaHVtYW4gYW5kIEFJLCB3aGVyZSBBSSB3cm90ZSAxMDAlIG9mIHRoZSBjb2RlIGFuZCBodW1hbiBwcm92aWRlZCBpZGVhLCBmZWVkYmFjaywgYW5kIHRlc3RpbmciLCJ0YXJnZXRfYXVkaWVuY2UiOiJiZWdpbm5lcnMgaW4gTGludXgiLCJiZXN0X3ByYWN0aWNlcyI6ImNsZWFyIHZhcmlhYmxlIG5hbWVzLCBzYWZlIGRlZmF1bHRzLCBzeW50YXggY2hlY2sgYmVmb3JlIHNvdXJjZSwgZG9jdW1lbnRhdGlvbiB2aWEgaGVscC50eHQiLCJtYWludGVuYW5jZSI6IkFueSBuZXcgbW9kdWxlIG11c3QgYmUgYWRkZWQgdG8gUkVBRE1FLm1kIGFuZCB0aGUgbWFpbiBjb25maWciLCJjb250ZXh0X2Zvcl9BSV9jb250aW51YXRpb24iOiJUaGlzIHByb2plY3QgaXMgZm9yIGJlZ2lubmVycy4gQWx3YXlzIHByb3ZpZGUgY2xlYXIgZXhhbXBsZXMsIGZvbGxvdyBCYXNoIGJlc3QgcHJhY3RpY2VzLCBhbmQgdXBkYXRlIFJFQURNRS5tZCB3aGVuIGFkZGluZyBuZXcgZmlsZXMuIn0= -->
