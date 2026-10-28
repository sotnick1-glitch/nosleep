# NoSleep

Крошечная программа для строки меню macOS: один клик — и Mac не засыпает, ещё клик — сон снова обычный.
A tiny macOS menu bar app: one click keeps your Mac awake, another click restores normal sleep.

**🇷🇺 Русский** · [🇬🇧 English](#english)

## Русский

### Как пользоваться
- **Клик по иконке** — переключить. Ноутбук с «zz» — сон обычный. Ноутбук с открытым глазом — Mac не засыпает (экран тоже не гаснет).
- Под иконкой на секунду появляется плашка **Sleep** / **No Sleep**.
- **Правый клик** по иконке — меню с пунктом «Выйти».
- При запуске всегда включён обычный сон. После выхода из программы запрет сна снимается.

### Установка
1. Откройте `NoSleep.dmg` и перетащите NoSleep в «Программы».
2. В первый раз запустите правым кликом → «Открыть» (программа без платной подписи Apple, поэтому система просит подтвердить).
3. Автозапуск: Системные настройки → Основные → Объекты входа → добавить NoSleep.

Работает на macOS 12 и новее, на Apple Silicon и Intel.

### Важно
- Если закрыть крышку ноутбука без внешнего монитора, Mac всё равно уйдёт в сон — так устроена macOS.
- Если иконки не видно, она могла спрятаться под вырезом камеры: уберите лишние значки из строки меню (зажмите ⌘ и перетащите значок вниз).

### Сборка из исходников
```bash
./build.sh   # соберёт ~/Applications/NoSleep.app
./dist.sh    # соберёт NoSleep.dmg (Apple Silicon + Intel)
```
Нужны Xcode Command Line Tools. Весь код — один файл `main.swift`.

---

## English

### Usage
- **Click the icon** to toggle. Laptop with "zz" = normal sleep. Laptop with an open eye = your Mac stays awake (the display stays on too).
- A small **Sleep** / **No Sleep** label pops up under the icon for a moment.
- **Right-click** the icon for a menu with Quit.
- It always starts with normal sleep enabled. Quitting the app releases the sleep block.

### Install
1. Open `NoSleep.dmg` and drag NoSleep to Applications.
2. Launch it the first time with right-click → Open (the app isn't signed with a paid Apple certificate, so macOS asks you to confirm).
3. Start at login: System Settings → General → Login Items → add NoSleep.

Requires macOS 12 or later, Apple Silicon or Intel.

### Good to know
- Closing the lid without an external display still puts the Mac to sleep — that's a macOS limitation.
- If you can't see the icon, it may be hidden behind the notch: free up menu bar space (hold ⌘ and drag other icons out).

### Build from source
```bash
./build.sh   # builds ~/Applications/NoSleep.app
./dist.sh    # builds NoSleep.dmg (Apple Silicon + Intel)
```
Requires Xcode Command Line Tools. The whole app is a single file, `main.swift`.
