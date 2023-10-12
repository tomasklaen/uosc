$ZipURL = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip"
$ConfURL = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf"

# Portable vs AppData install
if (Test-Path "$PWD/portable_config") {
	$DataDir = "$PWD/portable_config"
	Write-Output "Portable mode: $DataDir"
}
elseif ((Get-Item -Path $PWD).BaseName -eq "portable_config") {
	$DataDir = "$PWD"
	Write-Output "Portable mode: $DataDir"
}
else {
	$DataDir = "$env:APPDATA/mpv"
	Write-Output "AppData mode: $DataDir"
	if (!(Test-Path $DataDir)) {
		Write-Output "Creating folder: $DataDir"
		New-Item -ItemType Directory -Force -Path $DataDir > $null
	}
}

$ZipFile = "$DataDir/uosc_tmp.zip"

Function Cleanup() {
	try {
		if (Test-Path $ZipFile) {
			Write-Output "Deleting: $ZipFile"
			Remove-Item -LiteralPath $ZipFile -Force
		}
	}
	catch {}
}

Function Abort($Message) {
	Cleanup
	Write-Output "Error: $Message"
	Exit 1
}

# Remove old or deprecated folders & files
try {
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
		Write-Output "Deleting deprecated: $UoscDeprecatedFile"
		Remove-Item -LiteralPath $UoscDeprecatedFile -Force
	}
}
catch {
	Abort("Couldn't cleanup old files.")
}

# Install new version
try {
	Write-Output "Downloading: $ZipURL"
	Invoke-WebRequest -OutFile $ZipFile -Uri $ZipURL > $null
}
catch {
	Abort("Couldn't download the archive.")
}
try {
	Write-Output "Extracting: $ZipFile"
	Expand-Archive $ZipFile -DestinationPath $DataDir -Force > $null
}
catch {
	Abort("Couldn't extract the archive.")
}
Cleanup

# Download default config if one doesn't exist yet
try {
	$ScriptOptsDir = "$DataDir/script-opts"
	$ConfFile = "$ScriptOptsDir/uosc.conf"
	if (!(Test-Path $ConfFile)) {
		Write-Output "Config not found, downloading default one..."
		New-Item -ItemType Directory -Force -Path $ScriptOptsDir > $null
		Write-Output "Downloading: $ConfURL"
		Invoke-WebRequest -OutFile $ConfFile -Uri $ConfURL > $null
	}
}
catch {
	Abort("Couldn't download the config file, but uosc should be installed correctly.")
}

Write-Output "uosc has been installed."
