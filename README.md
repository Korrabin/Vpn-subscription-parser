# VPN Subscription Parser

Получайте, разделывайте и конвертируйте VPN-подписки в ключи, Sing-box JSON и Xray JSON на Windows, macOS и Linux.

Fetch, dissect, and convert VPN subscriptions into share keys, Sing-box JSON, and Xray JSON on Windows, macOS, and Linux.

[Русский](https://www.google.com/search?q=%23%D1%80%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9) · [English](https://www.google.com/search?q=%23english)

---

## Русский

### Возможности

* **3 формата вывода**: ключи (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`), готовый конфиг для Sing-box (с селектором и `urltest`) или форматированный Xray JSON.
* **Подмена устройства**: эмуляция платформы (`iOS`, `Android`, `Windows`, `macOS`, `Linux`), версии ОС, модели и `User-Agent` (Happ, INCY, Sing-box, v2RayTun, Mihomo, Karing).
* **Поддержка HWID**: автоматическая генерация стабильного аппаратного идентификатора (`x-hwid`) по спецификации панелей или ввод собственного.
* **Очистка от дублей**: фильтрация технических серверов и сводных профилей «Авто» с сохранением оригинальных названий узлов.
* **Проверка сети при старте**: экспресс-тест подключения к интернету перед переходом в основное меню.
* **Работа с буфером обмена**: автоматическое копирование результата для быстрой вставки (`Ctrl+V` / `Cmd+V`) в клиент.
* **Безопасное сохранение**: автоматическая запись файлов в текущую папку или каталог «Загрузки» без ошибок доступа.
* **Без сторонних зависимостей**: запуск на Windows в 1 клик через стандартную командную строку, на macOS и Linux — через системный Python.

### Форматы вывода

| Пункт меню | Формат | Назначение |
| --- | --- | --- |
| `1` | Стандартный JSON | Исходный или конвертированный JSON-конфиг (Xray, ручное редактирование) |
| `2` | Sing-box JSON | Полноценный готовый файл конфигурации с группами выбора и DNS |
| `3` | Sing-box Outbounds | Только массив `{"outbounds": [...]}` для роутеров и кастомных сборок |
| `4` | Ключи (URI) | Список ссылок для вставки в мобильные и десктопные клиенты |
| `5` | Все форматы | Одновременное сохранение всех вариантов в отдельные файлы |

### Запуск

* **Windows**: двойной клик по `VPN_Parser_Windows.cmd`
* **macOS / Linux**:
```bash
chmod +x VPN_Parser_Mac_Linux.sh
./VPN_Parser_Mac_Linux.sh

```



---

## English

### Features

* **3 output formats**: share keys (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`), full Sing-box JSON (with selector and `urltest`), or formatted Xray JSON.
* **Device emulation**: customizable platform (`iOS`, `Android`, `Windows`, `macOS`, `Linux`), OS version, device model, and `User-Agent` (Happ, INCY, Sing-box, v2RayTun, Mihomo, Karing).
* **HWID support**: automated generation of consistent hardware identifiers (`x-hwid`) matching panel requirements, or custom entry.
* **Node deduplication**: automated filtering of duplicated proxy entries and auto-balancer nodes while preserving original server remarks.
* **Startup network check**: quick verification of internet connectivity before loading the main menu.
* **Clipboard integration**: automatically copies generated output for instant pasting (`Ctrl+V` / `Cmd+V`) into your client.
* **Safe saving**: saves output files to the script folder or `Downloads` without permission issues.
* **Zero dependencies**: runs on Windows via native command prompt out of the box, and on macOS/Linux using standard system Python.

### Output formats

| Menu option | Format | Description |
| --- | --- | --- |
| `1` | Standard JSON | Raw or formatted JSON configuration (Xray, manual editing) |
| `2` | Sing-box JSON | Complete configuration file with selector, URLTest, and DNS |
| `3` | Sing-box Outbounds | Standalone `{"outbounds": [...]}` block for router and custom setups |
| `4` | Share keys (URI) | Direct link list for mobile and desktop VPN clients |
| `5` | All formats | Simultaneous export of all available formats into separate files |

### Quick start

* **Windows**: double-click `VPN_Parser_Windows.cmd`
* **macOS / Linux**:
```bash
chmod +x VPN_Parser_Mac_Linux.sh
./VPN_Parser_Mac_Linux.sh

```



---

## License

[MIT](https://www.google.com/search?q=LICENSE): free for personal and commercial use.
