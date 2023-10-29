# Package uosc release.

Function Abort($Message) {
	Write-Output "Error: $Message"
	Write-Output "Aborting!"
	Exit 1
}

Function DeleteIfExists($Path) {
	if (Test-Path $Path) {
		Remove-Item -LiteralPath $Path -Force -Recurse > $null
	}
}

if (!(Test-Path -Path "$PWD/src" -PathType Container)) {
	Abort("'src' directory not found. Make sure this script is run in uosc's repository root as current working directory.")
}

if (!(Test-Path -Path "$PWD/dist/scripts/uosc/bin/ziggy-linux" -PathType Leaf)) {
	Abort("'dist/scripts/uosc/bin' binaries are not build.")
}

$ReleaseDir = "release"

# Clear old
DeleteIfExists($ReleaseDir)
if (!(Test-Path $ReleaseDir)) {
	try {
		New-Item -ItemType Directory -Force -Path $ReleaseDir > $null
	}
	catch {
		Abort("Couldn't create release directory.")
	}
}

# Package new
$compress = @{
	LiteralPath = "dist/fonts", "dist/scripts"
	CompressionLevel = "Optimal"
	DestinationPath = "$ReleaseDir/uosc.zip"
}
Compress-Archive @compress
Copy-Item "dist/script-opts/uosc.conf" -Destination $ReleaseDir
