# Скрипт для установки APK на оба устройства

Write-Host "🚀 Установка Banka на устройства..." -ForegroundColor Cyan

# ID устройств
$device1 = "3B1F65E9CEQU0N7R"  # RMX5062 (Android 16) - Alice
$device2 = "W4ZXTKJVPFFQ89OF"  # RMX2155 (Android 12) - Bob

# Путь к APK (arm64-v8a подходит для обоих устройств)
$apkPath = "build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk"

# Проверка существования APK
if (-not (Test-Path $apkPath)) {
    Write-Host "❌ APK не найден: $apkPath" -ForegroundColor Red
    Write-Host "Запустите сначала: flutter build apk --debug --split-per-abi" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ APK найден: $apkPath" -ForegroundColor Green

# Установка на устройство 1 (Alice)
Write-Host "`n📱 Установка на устройство 1 (RMX5062 - Alice)..." -ForegroundColor Yellow
flutter install -d $device1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Установлено на устройство 1" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка установки на устройство 1" -ForegroundColor Red
}

# Установка на устройство 2 (Bob)
Write-Host "`n📱 Установка на устройство 2 (RMX2155 - Bob)..." -ForegroundColor Yellow
flutter install -d $device2

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Установлено на устройство 2" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка установки на устройство 2" -ForegroundColor Red
}

Write-Host "`n🎉 Готово! Приложение установлено на оба устройства." -ForegroundColor Cyan
Write-Host "📋 Следуйте инструкциям в TESTING_INSTRUCTIONS.md для тестирования" -ForegroundColor White
