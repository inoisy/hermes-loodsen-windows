<# : batch launcher, PowerShell skips this block as a comment
@echo off
chcp 65001 >nul
title Hermes Agent - uninstall
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:HL_SELF='%~f0'; Invoke-Expression ([IO.File]::ReadAllText($env:HL_SELF, [Text.Encoding]::UTF8))"
echo.
pause
exit /b
#>

# ============================================================================
# Удаление Hermes Agent, поставленного Install-Hermes-Loodsen.cmd
# Запуск: двойной клик по файлу. Права администратора не нужны.
# ============================================================================

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

$HermesHome = [Environment]::GetEnvironmentVariable('HERMES_HOME', 'User')
if (-not $HermesHome) { $HermesHome = Join-Path $env:LOCALAPPDATA 'hermes' }
$HermesHome = $HermesHome.TrimEnd('\')

Clear-Host
Say '=================================================' Cyan
Say '  Удаление Hermes Agent' Cyan
Say '=================================================' Cyan
Say ''
Say "Будет удалено всё, что связано с Hermes:"
Say "  - программа и её компоненты: $HermesHome"
Say '  - настройки, ключ доступа, история переписок и память агента;'
Say '  - ярлыки на рабочем столе и в меню «Пуск»;'
Say '  - записи Hermes в переменных среды пользователя.'
Say ''
Say 'Вернуть удалённое будет нельзя.' Yellow
$answer = Read-Host 'Удалить? Напишите «да» и нажмите Enter'
if ($answer.Trim() -notmatch '^(да|yes|y|д)$') {
    Say 'Отменено, ничего не удалено.' Green
    exit 0
}

# --- 1. Остановить процессы Hermes (дашборд, агент, gateway) ----------------
Say ''
Say '[1/5] Останавливаю Hermes...' Cyan
$prefix = $HermesHome + '\'
$procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessId -ne $PID -and (
        ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) -or
        ($_.CommandLine -and $_.CommandLine.IndexOf($HermesHome, [StringComparison]::OrdinalIgnoreCase) -ge 0)) })
foreach ($p in $procs) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}
Say "  остановлено процессов: $($procs.Count)" DarkGray
Start-Sleep -Seconds 2

# --- 2. Автозапуск gateway (если его включали) ------------------------------
Say '[2/5] Убираю автозапуск...' Cyan
$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'Hermes_Gateway*' })
foreach ($t in $tasks) {
    Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
}
$startup = [Environment]::GetFolderPath('Startup')
Get-ChildItem -LiteralPath $startup -Filter 'Hermes_Gateway*' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# --- 3. Ярлыки --------------------------------------------------------------
Say '[3/5] Удаляю ярлыки...' Cyan
$shell = New-Object -ComObject WScript.Shell
$dirs = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))
foreach ($dir in $dirs) {
    Get-ChildItem -LiteralPath $dir -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
        $target = ''
        try { $target = $shell.CreateShortcut($_.FullName).TargetPath } catch { }
        if ($target -and $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            Say "  удалён ярлык: $($_.Name)" DarkGray
        }
    }
}

# --- 4. PATH и переменные среды пользователя --------------------------------
Say '[4/5] Чищу переменные среды...' Cyan
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
    $kept = @($userPath -split ';' | Where-Object {
        $_ -and -not ($_.TrimEnd('\') + '\').StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
    [Environment]::SetEnvironmentVariable('Path', ($kept -join ';'), 'User')
}
foreach ($name in @('HERMES_HOME', 'HERMES_GIT_BASH_PATH')) {
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $null) {
        [Environment]::SetEnvironmentVariable($name, $null, 'User')
    }
}

# --- 5. Файлы ---------------------------------------------------------------
Say '[5/5] Удаляю файлы (может занять пару минут)...' Cyan
if (Test-Path -LiteralPath $HermesHome) {
    # attrib снимает «только чтение» (так помечены файлы git), rd через \\?\
    # проходит пути длиннее 260 символов в node_modules.
    & cmd /c "attrib -r -h -s `"$HermesHome\*`" /s /d >nul 2>&1"
    & cmd /c "rd /s /q `"\\?\$HermesHome`" >nul 2>&1"
    if (Test-Path -LiteralPath $HermesHome) {
        Start-Sleep -Seconds 3
        & cmd /c "rd /s /q `"\\?\$HermesHome`" >nul 2>&1"
    }
}

Say ''
if (Test-Path -LiteralPath $HermesHome) {
    Say 'Почти всё удалено, но часть файлов занята другой программой:' Yellow
    Say "  $HermesHome" Yellow
    Say 'Перезагрузите компьютер и запустите удаление ещё раз.' Yellow
} else {
    Say '=================================================' Green
    Say '  Hermes удалён.' Green
    Say '=================================================' Green
    Say 'Ключ API на ai.loodsen.ru остался действующим. Если он больше не нужен,'
    Say 'удалите его там: аватар -> Настройки -> Аккаунт -> API ключи.'
}
