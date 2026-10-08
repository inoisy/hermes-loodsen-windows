# Hermes Agent для Windows 11 с моделью GLM (ai.loodsen.ru)

Установщик [Hermes Agent](https://github.com/NousResearch/hermes-agent) для тех, кто не разработчик:
двойной клик, вставить ключ API — и агент работает с моделью `GLM-5.3-Flash-coder` с `ai.loodsen.ru`.

## Установка

1. Скачайте `Hermes-Loodsen-Windows.zip` со страницы [Releases](../../releases/latest).
2. Распакуйте архив целиком (правой кнопкой → «Извлечь все…»).
3. Дважды щёлкните `Install-Hermes-Loodsen.cmd` и следуйте подсказкам.
   Ключ API: `ai.loodsen.ru` → аватар → Настройки → Аккаунт → API ключи.

Права администратора не нужны. Установка занимает 10–20 минут и докачивает Git, uv, Python,
Node и Python-пакеты; сами исходники Hermes лежат в архиве (`hermes-agent.zip`).

После установки на рабочем столе:
- **Hermes в браузере** — веб-чат на `http://127.0.0.1:9119`;
- **Hermes (Лоция)** — то же в терминале.

## Удаление

`Uninstall-Hermes-Loodsen.cmd` → подтвердить словом «да». Удаляет программу, настройки, ключ,
историю, ярлыки и записи в PATH.

## Что настраивает установщик

- провайдер `loodsen` (`https://ai.loodsen.ru/api/v1`, OpenAI-совместимый), ключ в `%LOCALAPPDATA%\hermes\.env`;
- модель `GLM-5.3-Flash-coder`; `context_length: 64000` — сервер режет запрос примерно после 50k токенов,
  так Hermes сжимает историю раньше обрезки;
- `thinking` не выключается: с `thinking: false` GLM пишет рассуждения прямо в ответ;
- отправка метрик в Nous Research выключена;
- `SOUL.md`: отвечать по-русски и простым языком.

Официальный `install.ps1` из архива запускается по этапам, кроме `repository` (клон с GitHub)
и интерактивных `setup`/`gateway`.

## Сборка архива

```bash
./build-bundle.sh          # main
./build-bundle.sh v0.21.6  # конкретный тег
```
