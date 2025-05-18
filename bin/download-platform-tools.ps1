$ErrorActionPreference = "Stop"

# Determine correct BinPath based on current directory
$CurrentDir = Get-Location
if ($CurrentDir.Path -match "\\bin$") {
    $BinPath = "platform-tools"
} else {
    $BinPath = "bin/platform-tools"
}

$GnirehtetApi = "https://api.github.com/repos/Genymobile/gnirehtet/releases/latest"
$ScrcpyApi = "https://api.github.com/repos/Genymobile/scrcpy/releases/latest"
$GnirehtetXApi = "https://api.github.com/repos/Linus789/gnirehtetx/releases/latest"

# Ensure target folder exists
if (-Not (Test-Path $BinPath)) {
    New-Item -ItemType Directory -Force -Path $BinPath | Out-Null
}

# --- Download and extract latest Gnirehtet ---
Write-Host "Fetching latest Gnirehtet release info..."
$GnirehtetJson = Invoke-RestMethod -Uri $GnirehtetApi
$GnirehtetUrl = ($GnirehtetJson.assets | Where-Object { $_.name -like "*win64*" -and $_.name -like "*.zip" } | Select-Object -First 1).browser_download_url

Write-Host "Downloading Gnirehtet from $GnirehtetUrl..."
$GnirehtetZip = "gnirehtet.zip"
$TempGnirehtet = Join-Path $env:TEMP "gnirehtet-temp"
Invoke-WebRequest -Uri $GnirehtetUrl -OutFile $GnirehtetZip
# --- Gnirehtet Extraction ---
Expand-Archive -Force -Path $GnirehtetZip -DestinationPath $TempGnirehtet
$GnirehtetInner = Get-ChildItem -Path $TempGnirehtet | Where-Object { $_.PSIsContainer } | Select-Object -First 1
if ($GnirehtetInner) {
    Move-Item -Path (Join-Path $GnirehtetInner.FullName "*") -Destination $BinPath -Force
}
Remove-Item $GnirehtetZip
Remove-Item $TempGnirehtet -Recurse -Force

# --- Download and extract latest Scrcpy ---
Write-Host "Fetching latest Scrcpy release info..."
$ScrcpyJson = Invoke-RestMethod -Uri $ScrcpyApi
$ScrcpyUrl = ($ScrcpyJson.assets | Where-Object { $_.name -like "*win64*" -and $_.name -like "*.zip" } | Select-Object -First 1).browser_download_url

Write-Host "Downloading Scrcpy..."
$ScrcpyZip = "scrcpy.zip"
$TempScrcpy = Join-Path $env:TEMP "scrcpy-temp"
Invoke-WebRequest -Uri $ScrcpyUrl -OutFile $ScrcpyZip

# --- Scrcpy Extraction ---
Expand-Archive -Force -Path $ScrcpyZip -DestinationPath $TempScrcpy
$ScrcpyInner = Get-ChildItem -Path $TempScrcpy | Where-Object { $_.PSIsContainer } | Select-Object -First 1
if ($ScrcpyInner) {
    Move-Item -Path (Join-Path $ScrcpyInner.FullName "*") -Destination $BinPath -Force
}
Remove-Item $ScrcpyZip
Remove-Item $TempScrcpy -Recurse -Force

# --- Download and rename gnirehtet.apk ---
Write-Host "Fetching gnirehtetx APK..."
$GnirehtetXJson = Invoke-RestMethod -Uri $GnirehtetXApi
$AltApkUrl = ($GnirehtetXJson.assets | Where-Object name -eq "app-release.apk" | Select-Object -First 1).browser_download_url

$ApkPath = Join-Path $BinPath "gnirehtet.apk"
if (Test-Path $ApkPath) {
    Remove-Item $ApkPath
}

Write-Host "Downloading and renaming APK..."
Invoke-WebRequest -Uri $AltApkUrl -OutFile $ApkPath

Write-Host "`n✅ All tools downloaded and updated in '$BinPath'"