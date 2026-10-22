# ساخت آزمایشی گوشی با ابزارهای مشترک؛ برنامهٔ تبلت تغییر نمی‌کند.
$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'F:\_DevTools\android-toolchain\jdk\jdk-17.0.20.1+1'
$env:ANDROID_HOME = 'F:\_DevTools\android-toolchain\android-sdk'
$env:GRADLE_USER_HOME = 'F:\_DevTools\gradle-flutter'
Push-Location $PSScriptRoot
try {
    & 'F:\_DevTools\flutter\bin\flutter.bat' build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'ساخت APK ناموفق بود؛ خروجی ابزار را بررسی کنید.' }
} finally {
    Pop-Location
}
