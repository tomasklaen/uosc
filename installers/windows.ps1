$ZipURL = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip"
$ConfURL = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf"

# Portable vs AppData install
if (Test-Path "$PWD/portable_config") {
	$DataDir = "$PWD/portable_config"
	Write-Output "Portable mode: $DataDir"
} elseif ((Get-Item -Path $PWD).BaseName -eq "portable_config") {
	$DataDir = "$PWD"
	Write-Output "Portable mode: $DataDir"
} else {
	$DataDir = "$env:APPDATA/mpv"
	Write-Output "AppData mode: $DataDir"
	if (!(Test-Path $DataDir)) {
		Write-Output "Creating folder: $DataDir"
		New-Item -ItemType Directory -Force -Path $DataDir > $null
	}
}

# Remove old or deprecated folders & files
$UoscDir = "$DataDir/scripts/uosc"
$UoscDeprecatedDir = "$DataDir/scripts/uosc_shared"
$UoscDeprecatedFile = "$DataDir/scripts/uosc.lua"
if (Test-Path $UoscDir) {
	Write-Output "Deleting old: $UoscDir"
	Remove-Item -LiteralPath $UoscDir -Force -Recurse
}
if (Test-Path $UoscDeprecatedDir) {
	Write-Output "Deleting deprecated: $UoscDeprecatedDir"
	Remove-Item -LiteralPath $UoscDeprecatedDir -Force -Recurse
}
if (Test-Path $UoscDeprecatedFile) {
	Write-Output "Deleting deprecated: $UoscDeprecatedDir"
	Remove-Item -LiteralPath $UoscDeprecatedFile -Force
}

# Install new version
$ZipFile = "$DataDir/uosc_tmp.zip"
Write-Output "Downloading: $ZipURL"
Invoke-WebRequest -OutFile $ZipFile -Uri $ZipURL > $null
Write-Output "Extracting: $ZipFile"
Expand-Archive $ZipFile -DestinationPath $DataDir -Force > $null
Write-Output "Deleting: $ZipFile"
Remove-Item $ZipFile

# Download default config if one doesn't exist yet
$ScriptOptsDir = "$DataDir/script-opts"
$ConfFile = "$ScriptOptsDir/uosc.conf"
if (!(Test-Path $ConfFile)) {
	Write-Output "Config not found."
	New-Item -ItemType Directory -Force -Path $ScriptOptsDir > $null
	Write-Output "Downloading: $ConfURL"
	Invoke-WebRequest -OutFile $ConfFile -Uri $ConfURL > $null
}

Write-Output "uosc has been installed."
