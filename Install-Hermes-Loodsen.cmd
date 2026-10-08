<# : batch launcher, PowerShell skips this block as a comment
@echo off
chcp 65001 >nul
title Hermes Agent - Lotsiya
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:HL_SELF='%~f0'; Invoke-Expression ([IO.File]::ReadAllText($env:HL_SELF, [Text.Encoding]::UTF8))"
echo.
pause
exit /b
#>

# ============================================================================
# Установщик Hermes Agent для Windows 11 с моделью GLM из ai.loodsen.ru
# Запуск: двойной клик по файлу. Права администратора не нужны.
# ============================================================================

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ApiBase    = 'https://ai.loodsen.ru/api/v1'
$KeyEnvName = 'CUSTOM_AI_LOODSEN_RU_API_KEY'
$MainModel  = 'GLM-5.3-Flash-coder'
$BundleZip  = Join-Path (Split-Path -Parent $env:HL_SELF) 'hermes-agent.zip'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Step($n, $text) { Write-Host ''; Write-Host "[$n/5] $text" -ForegroundColor Cyan }
function Fail($text) {
    Write-Host ''
    Write-Host "ОШИБКА: $text" -ForegroundColor Red
    Write-Host 'Сделайте скриншот этого окна и отправьте тому, кто дал вам установщик.' -ForegroundColor Yellow
    exit 1
}

function Test-LoodsenKey([string]$key) {
    try {
        $r = Invoke-RestMethod -Uri "$ApiBase/models" -Headers @{ Authorization = "Bearer $key" } -TimeoutSec 30
        return [bool]($r.data | Where-Object { $_.id -eq $MainModel })
    } catch {
        return $false
    }
}

Clear-Host
Say '=================================================' Cyan
Say '  Установка Hermes Agent с моделью GLM (Лоция)' Cyan
Say '=================================================' Cyan
Say ''
Say 'Займёт 10-20 минут. Окно не закрывайте, пока не увидите «Готово».'
Say 'Нужен интернет и доступ к ai.loodsen.ru (если сайт открывается только через VPN — включите VPN).'

# --- 1. Ключ API ------------------------------------------------------------
Step 1 'Ключ доступа к модели'
Say 'Где взять ключ:'
Say '  1) откройте https://ai.loodsen.ru и войдите;'
Say '  2) нажмите на свой аватар (внизу слева) -> «Настройки» -> «Аккаунт»;'
Say '  3) в блоке «API ключи» нажмите «Создать» / «Показать» и скопируйте ключ (начинается с sk-).'
Say ''
$open = Read-Host 'Открыть сайт в браузере сейчас? (Д/н)'
if ($open -notmatch '^[nNнН]') { Start-Process 'https://ai.loodsen.ru' }

$apiKey = $null
for ($try = 1; $try -le 5; $try++) {
    Say ''
    Say 'Вставьте ключ правой кнопкой мыши (или Ctrl+V) и нажмите Enter.' Yellow
    Say 'Символы на экране не отображаются — так и должно быть.' DarkGray
    $secure = Read-Host 'Ключ' -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)).Trim()
    if (-not $plain) { Say 'Пусто. Попробуйте ещё раз.' Red; continue }
    Say 'Проверяю ключ...'
    if (Test-LoodsenKey $plain) { $apiKey = $plain; Say 'Ключ рабочий, модель доступна.' Green; break }
    Say "Ключ не подошёл, или нет доступа к ai.loodsen.ru, или ключу не открыта модель $MainModel." Red
}
if (-not $apiKey) { Fail 'не удалось проверить ключ за 5 попыток.' }

# Клик мышью по окну включает в консоли режим выделения («Выбрать» в заголовке),
# и установка встаёт на паузу до Esc. Ключ уже вставлен — режим выделения больше не нужен.
try {
    Add-Type -Namespace HL -Name ConsoleMode -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
    $hIn = [HL.ConsoleMode]::GetStdHandle(-10)
    $mode = [uint32]0
    if ([HL.ConsoleMode]::GetConsoleMode($hIn, [ref]$mode)) {
        # снять ENABLE_QUICK_EDIT_MODE (0x40), выставить ENABLE_EXTENDED_FLAGS (0x80)
        [void][HL.ConsoleMode]::SetConsoleMode($hIn, (($mode -band (-bnot 0x40)) -bor 0x80))
    }
} catch { }
Say ''
Say 'Не щёлкайте мышью внутри этого окна до конца установки.' Yellow
Say 'Если в заголовке окна появилось слово «Выбрать» — нажмите Esc, иначе установка встанет на паузу.' Yellow

# --- 2. Установка Hermes ---------------------------------------------------
Step 2 'Устанавливаю Hermes Agent (самая долгая часть)'
Say 'По экрану побегут технические сообщения на английском — это нормально.' DarkGray

$HermesHome = [Environment]::GetEnvironmentVariable('HERMES_HOME', 'User')
if (-not $HermesHome) { $HermesHome = Join-Path $env:LOCALAPPDATA 'hermes' }
$InstallDir = Join-Path $HermesHome 'hermes-agent'
New-Item -ItemType Directory -Force -Path $HermesHome | Out-Null

# Исходники Hermes лежат рядом в hermes-agent.zip — с GitHub не качаем.
if (Test-Path (Join-Path $InstallDir '.git')) {
    Say "Hermes уже был установлен в $InstallDir — исходники не трогаю, доустанавливаю зависимости." DarkGray
} else {
    if (-not (Test-Path -LiteralPath $BundleZip)) {
        Fail "рядом с установщиком нет файла hermes-agent.zip. Распакуйте архив целиком и запускайте установщик из распакованной папки."
    }
    if ((Test-Path -LiteralPath $InstallDir) -and (Get-ChildItem -LiteralPath $InstallDir -Force | Select-Object -First 1)) {
        Fail "папка $InstallDir уже существует и не похожа на Hermes. Переименуйте её и запустите установщик снова."
    }
    Say 'Распаковываю исходники Hermes...'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $staging = Join-Path $HermesHome ".unpack-$PID"
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    try {
        [IO.Compression.ZipFile]::ExtractToDirectory($BundleZip, $staging)
    } catch {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
        Fail "не удалось распаковать hermes-agent.zip: $($_.Exception.Message)"
    }
    Remove-Item -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath (Join-Path $staging 'hermes-agent') -Destination $InstallDir
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    Say 'Исходники на месте.' Green
}

# Официальный установщик из тех же исходников, все этапы кроме скачивания
# репозитория (repository) и интерактивных (setup, gateway).
$installPs1 = Join-Path $InstallDir 'scripts\install.ps1'
foreach ($stage in @('prerequisites', 'venv', 'python-deps', 'config', 'products', 'complete')) {
    Say "  этап: $stage" DarkGray
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installPs1 -Stage $stage -NonInteractive -HermesHome $HermesHome -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0) { Fail "этап установки «$stage» завершился с ошибкой (код $LASTEXITCODE)." }
}

$HermesExe = Join-Path $HermesHome 'bin\hermes.exe'
if (-not (Test-Path $HermesExe)) { $HermesExe = Join-Path $HermesHome 'bin\hermes.cmd' }
if (-not (Test-Path $HermesExe)) { Fail "Hermes не установился: нет команды hermes в $HermesHome\bin" }
Say 'Hermes установлен.' Green

# --- 3. Настройки под модель Лоции -----------------------------------------
Step 3 'Прописываю настройки модели'
New-Item -ItemType Directory -Force -Path $HermesHome | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$utf8 = New-Object Text.UTF8Encoding($false)

# Ключ — в .env (остальные строки, если были, сохраняются)
$envFile = Join-Path $HermesHome '.env'
$envLines = @()
if (Test-Path $envFile) {
    Copy-Item $envFile "$envFile.bak.$stamp"
    $envLines = @(Get-Content $envFile -Encoding UTF8 | Where-Object { $_ -notmatch "^$KeyEnvName=" })
}
$envLines += "$KeyEnvName=$apiKey"
[IO.File]::WriteAllLines($envFile, [string[]]$envLines, $utf8)

# Конфиг. Почему так:
#  - GLM-5.3-Flash (без суффикса) на сервере больше нет, берём -coder;
#  - thinking не выключаем: с thinking:false модель пишет рассуждения прямо в ответ;
#  - сервер режет запрос примерно после 50k токенов, поэтому контекст объявлен 64k —
#    Hermes будет сжимать историю раньше, чем сервер начнёт обрезать.
$configFile = Join-Path $HermesHome 'config.yaml'
if (Test-Path $configFile) { Copy-Item $configFile "$configFile.bak.$stamp" }
$config = @"
model:
  default: $MainModel
  provider: loodsen
  max_tokens: 8000
custom_providers:
  - name: loodsen
    base_url: $ApiBase
    api_key_env: $KeyEnvName
    api_mode: chat_completions
    discover_models: false
    models:
      ${MainModel}:
        context_length: 64000
        max_tokens: 8000
compression:
  enabled: true
  threshold: 0.5
telemetry:
  shared_metrics:
    enabled: false
    send: false
    offer_version: 2
auxiliary:
  compression:
    provider: loodsen
    model: $MainModel
    timeout: 120
  title_generation:
    provider: loodsen
    model: $MainModel
    timeout: 30
"@
[IO.File]::WriteAllText($configFile, $config, $utf8)

$soulFile = Join-Path $HermesHome 'SOUL.md'
if (-not (Test-Path $soulFile)) {
    [IO.File]::WriteAllText($soulFile, "Ты — Hermes, ИИ-помощник. Всегда отвечай на русском языке, понятно и без лишнего жаргона: пользователь не программист. Перед действиями, которые что-то меняют на компьютере, коротко объясняй, что собираешься сделать.`n", $utf8)
}
Say "Настройки записаны в $HermesHome" Green

# --- 4. Ярлык на рабочем столе ---------------------------------------------
Step 4 'Создаю ярлык на рабочем столе'
try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $desktop 'Hermes (Лоция).lnk'))
    $lnk.TargetPath = $HermesExe
    $lnk.WorkingDirectory = $env:USERPROFILE
    $lnk.Description = 'Hermes Agent с моделью GLM ai.loodsen.ru'
    $lnk.Save()
    $web = $shell.CreateShortcut((Join-Path $desktop 'Hermes в браузере.lnk'))
    $web.TargetPath = $HermesExe
    $web.Arguments = 'dashboard'
    $web.WorkingDirectory = $env:USERPROFILE
    $web.WindowStyle = 7
    $web.Description = 'Веб-интерфейс Hermes: http://127.0.0.1:9119'
    $web.Save()
    Say 'Ярлыки «Hermes (Лоция)» и «Hermes в браузере» созданы.' Green
} catch {
    Say "Ярлык создать не удалось ($($_.Exception.Message)). Запускайте Hermes командой hermes в PowerShell." Yellow
}

# --- 5. Проверка -----------------------------------------------------------
Step 5 'Проверяю, что агент отвечает'
$env:HERMES_HOME = $HermesHome
$ErrorActionPreference = 'Continue'
$answer = & $HermesExe -z 'Ответь одним словом: работаешь?' 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -and $answer.Trim()) {
    Say "Ответ модели: $($answer.Trim())" Green
} else {
    Say 'Проверочный запрос не прошёл. Вывод:' Yellow
    Say $answer DarkGray
    Say 'Попробуйте всё равно открыть ярлык. Если не работает — пришлите скриншот.' Yellow
}

# --- Веб-интерфейс: первый запуск собирает его (пара минут), дальше стартует сразу
Say ''
Say 'Готовлю веб-интерфейс (первый запуск, до 5 минут)...' Cyan
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
Start-Process -FilePath $HermesExe -ArgumentList 'dashboard' -WorkingDirectory $env:USERPROFILE -WindowStyle Minimized | Out-Null
$webOk = $false
for ($i = 0; $i -lt 150; $i++) {
    Start-Sleep -Seconds 2
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:9119/' -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $webOk = $true; break }
    } catch { }
}
if ($webOk) {
    Say 'Веб-интерфейс открыт в браузере: http://127.0.0.1:9119 (вкладка Chat).' Green
} else {
    Say 'Веб-интерфейс не поднялся за 5 минут. Откройте ярлык «Hermes в браузере» ещё раз чуть позже.' Yellow
}

Say ''
Say '=================================================' Green
Say '  Готово!' Green
Say '=================================================' Green
Say 'Как пользоваться:'
Say '  - «Hermes в браузере» на рабочем столе — чат в браузере (вкладка Chat слева);'
Say '    свёрнутое окно Hermes в панели задач не закрывайте, пока работаете в браузере;'
Say '  - «Hermes (Лоция)» — то же самое в чёрном окне терминала;'
Say '  - пишите задачу обычным текстом и жмите Enter;'
Say '  - если агент спрашивает разрешение выполнить команду — читайте, что он хочет сделать, и отвечайте;'
Say '  - выйти: набрать /exit или закрыть окно.'
