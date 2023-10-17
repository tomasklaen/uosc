$ZipURL = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip"
$ConfURL = "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf"
$Files = "scripts/uosc", "fonts/uosc_icons.otf", "fonts/uosc_textures.ttf", "scripts/uosc_shared", "scripts/uosc.lua"

# Determine install directory
if (Test-Path env:MPV_CONFIG_DIR) {
	Write-Output "Installing into (MPV_CONFIG_DIR):"
	$ConfigDir = "$env:MPV_CONFIG_DIR"
}
elseif (Test-Path "$PWD/portable_config") {
	Write-Output "Installing into (portable config):"
	$ConfigDir = "$PWD/portable_config"
}
elseif ((Get-Item -Path $PWD).BaseName -eq "portable_config") {
	Write-Output "Installing into (portable config):"
	$ConfigDir = "$PWD"
}
else {
	Write-Output "Installing into (current user config):"
	$ConfigDir = "$env:APPDATA/mpv"
	if (!(Test-Path $ConfigDir)) {
		Write-Output "Creating folder: $ConfigDir"
		New-Item -ItemType Directory -Force -Path $ConfigDir > $null
	}
}

Write-Output "→ $ConfigDir"

$BackupDir = "$ConfigDir/.uosc-backup"
$ZipFile = "$ConfigDir/uosc_tmp.zip"

function DeleteIfExists($Path) {
	if (Test-Path $Path) {
		Remove-Item -LiteralPath $Path -Force -Recurse > $null
	}
}

Function Abort($Message) {
	Write-Output "Error: $Message"
	Write-Output "Aborting!"

	DeleteIfExists($ZipFile)

	Write-Output "Deleting potentially broken install..."
	foreach ($File in $Files) {
		DeleteIfExists("$ConfigDir/$File")
	}

	Write-Output "Restoring backup..."
	foreach ($File in $Files) {
		$FromPath = "$BackupDir/$File"
		if (Test-Path $FromPath) {
			$ToPath = "$ConfigDir/$File"
			$ToDir = Split-Path $ToPath -parent
			New-Item -ItemType Directory -Force -Path $ToDir > $null
			Move-Item -LiteralPath $FromPath -Destination $ToPath -Force > $null
		}
	}

	Write-Output "Deleting backup..."
	DeleteIfExists($BackupDir)

	Exit 1
}

# Ensure install directory exists
if (!(Test-Path -Path $ConfigDir -PathType Container)) {
	if (Test-Path -Path $ConfigDir -PathType Leaf) {
		Abort("Config directory is a file.")
	}
	try {
		New-Item -ItemType Directory -Force -Path $ConfigDir > $null
	}
	catch {
		Abort("Couldn't create config directory.")
	}
}

Write-Output "Backing up..."
foreach ($File in $Files) {
	$FromPath = "$ConfigDir/$File"
	if (Test-Path $FromPath) {
		$ToPath = "$BackupDir/$File"
		$ToDir = Split-Path $ToPath -parent
		try {
			New-Item -ItemType Directory -Force -Path $ToDir > $null
		}
		catch {
			Abort("Couldn't create backup folder: $ToDir")
		}
		try {
			Move-Item -LiteralPath $FromPath -Destination $ToPath -Force > $null
		}
		catch {
			Abort("Couldn't move '$FromPath' to '$ToPath'.")
		}
	}
}

# Install new version
Write-Output "Downloading archive..."
try {
	Invoke-WebRequest -OutFile $ZipFile -Uri $ZipURL > $null
}
catch {
	Abort("Couldn't download: $ZipURL")
}
Write-Output "Extracting archive..."
try {
	Expand-Archive $ZipFile -DestinationPath $ConfigDir -Force > $null
}
catch {
	Abort("Couldn't extract: $ZipFile")
}
Write-Output "Deleting archive..."
DeleteIfExists($ZipFile)
Write-Output "Deleting backup..."
DeleteIfExists($BackupDir)

# Download default config if one doesn't exist yet
try {
	$ScriptOptsDir = "$ConfigDir/script-opts"
	$ConfFile = "$ScriptOptsDir/uosc.conf"
	if (!(Test-Path $ConfFile)) {
		Write-Output "Config not found, downloading default uosc.conf..."
		New-Item -ItemType Directory -Force -Path $ScriptOptsDir > $null
		Invoke-WebRequest -OutFile $ConfFile -Uri $ConfURL > $null
	}
}
catch {
	Abort("Couldn't download the config file, but uosc should be installed correctly.")
}

Write-Output "uosc has been installed."
