# scripts/devlog.ps1 — компактный лог приложения на телефоне для отладки.
#
# Перезапускает приложение и печатает ТОЛЬКО строки Dart (flutter) и фатальные
# ошибки, отсекая системный шум устройства (Oplus/SmartSidebar и т.п.).
# Нужен, чтобы при отладке не тащить в контекст гигантский сырой logcat.
#
# Использование:
#   pwsh scripts/devlog.ps1                 # перезапуск приложения + последние строки flutter
#   pwsh scripts/devlog.ps1 -Seconds 12 -Tail 60
#   pwsh scripts/devlog.ps1 -NoRestart      # не перезапускать, просто снять текущий лог
param(
  [int]$Seconds   = 8,
  [int]$Tail      = 40,
  [string]$Device = '3B1F65E9CEQU0N7R',
  [string]$Package = 'com.retrobich921.banka',
  [switch]$NoRestart
)

$adb = 'C:\Android\platform-tools\adb.exe'

if (-not $NoRestart) {
  & $adb -s $Device shell am force-stop $Package
  & $adb -s $Device logcat -c
  & $adb -s $Device shell am start -n "$Package/.MainActivity" | Out-Null
  Start-Sleep -Seconds $Seconds
}

& $adb -s $Device logcat -d |
  Select-String -Pattern 'flutter :|FATAL|AndroidRuntime' |
  Select-String -NotMatch -Pattern 'SmartSidebar|OplusNotification|getForegroundApplication|EdgePanel|VideoAssistant|Impeller' |
  Select-Object -Last $Tail
