# Script to build one of uosc binaries.
# Requirements: go, upx (if compressing)
# Usage: tools/build <name> [-c]
# <name> can be: intl, ziggy
# -c enables binary compression with upx (only needed for builds being released)

Function Abort($Message) {
	Write-Output "Error: $Message"
	Write-Output "Aborting!"
	Exit 1
}

if (!(Test-Path -Path "$PWD/src" -PathType Container)) {
	Abort("'src' directory not found. Make sure this script is run in uosc's repository root as current working directory.")
}

if ($args[0] -eq "intl") {
	$env:GOARCH = "amd64"
	$Src = "./src/intl/intl.go"
	$OutDir = "./tools"

	Write-Output "Building for Windows..."
	$env:GOOS = "windows"
	go build -ldflags "-s -w" -o "$OutDir/intl.exe" $Src

	Write-Output "Building for Linux..."
	$env:GOOS = "linux"
	go build -ldflags "-s -w" -o "$OutDir/intl-linux" $Src

	Write-Output "Building for MacOS..."
	$env:GOOS = "darwin"
	go build -ldflags "-s -w" -o "$OutDir/intl-darwin" $Src

	if ($args[1] -eq "-c") {
		Write-Output "Compressing binaries..."
		upx --brute "$OutDir/intl.exe"
		upx --brute "$OutDir/intl-linux"
		upx --brute "$OutDir/intl-darwin"
	}

	Remove-Item Env:\GOOS
	Remove-Item Env:\GOARCH
}
elseif ($args[0] -eq "ziggy") {
	$env:GOARCH = "amd64"
	$Src = "./src/ziggy/ziggy.go"
	$OutDir = "./dist/scripts/uosc/bin"

	if (!(Test-Path $OutDir)) {
		New-Item -ItemType Directory -Force -Path $OutDir > $null
	}

	Write-Output "Building for Windows..."
	$env:GOOS = "windows"
	go build -ldflags "-s -w" -o "$OutDir/ziggy-windows.exe" $Src

	Write-Output "Building for Linux..."
	$env:GOOS = "linux"
	go build -ldflags "-s -w" -o "$OutDir/ziggy-linux" $Src

	Write-Output "Building for MacOS..."
	$env:GOOS = "darwin"
	go build -ldflags "-s -w" -o "$OutDir/ziggy-darwin" $Src

	if ($args[1] -eq "-c") {
		Write-Output "Compressing binaries..."
		upx --brute "$OutDir/ziggy-windows.exe"
		upx --brute "$OutDir/ziggy-linux"
		upx --brute "$OutDir/ziggy-darwin"
	}

	Remove-Item Env:\GOOS
	Remove-Item Env:\GOARCH
}
else {
	Write-Output "Tool to build one of uosc binaries."
	Write-Output "Requirements: go, upx (if compressing)"
	Write-Output "Usage: tools/build <name> [-c]"
	Write-Output "<name> can be: intl, ziggy"
	Write-Output "-c enables binary compression (requires upx)"
}
