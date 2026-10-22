# فقط اجرای خودکار برنامه؛ پشتیبان‌گیری خودکار به درخواست مالک حذف شده است.
$ErrorActionPreference = 'Stop'
$homaExecutable = 'F:\Homa\software\windows\build\windows\x64\runner\Release\homa_control.exe'
if (-not (Test-Path -LiteralPath $homaExecutable)) { throw 'Homa executable missing' }
$homaRunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-ItemProperty -LiteralPath $homaRunKey -Name 'HomaControl' -PropertyType String -Value ('"' + $homaExecutable + '"') -Force | Out-Null
Write-Output 'Autostart enabled. Automatic backup is disabled by owner request.'
