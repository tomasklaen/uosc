# Script to build one of uosc binaries.
# Requirements: go, upx (if compressing)
# Usage: tools/build <name> [-c]
# <name> can be: tools, ziggy
# -c enables binary compression with upx (only needed for builds being released)

Function Abort($Message) {
	Write-Output "Error: $Message"
	Write-Output "Aborting!"
	Exit 1
}

if (!(Test-Path -Path "$PWD/src" -PathType Container)) {
	Abort("'src' directory not found. Make sure this script is run in uosc's repository root as current working directory.")
}

if ($args[0] -eq "tools") {
	$env:GOARCH = "amd64"
	$Src = "./src/tools/tools.go"
	$OutDir = "./tools"

	Write-Output "Building for Windows..."
	$env:GOOS = "windows"
	go build -ldflags "-s -w" -o "$OutDir/tools.exe" $Src

	Write-Output "Building for Linux..."
	$env:GOOS = "linux"
	go build -ldflags "-s -w" -o "$OutDir/tools-linux" $Src

	Write-Output "Building for MacOS..."
	$env:GOOS = "darwin"
	go build -ldflags "-s -w" -o "$OutDir/tools-darwin" $Src

	if ($args[1] -eq "-c") {
		Write-Output "Compressing binaries..."
		upx --brute "$OutDir/tools.exe"
		upx --brute "$OutDir/tools-linux"
		upx --brute "$OutDir/tools-darwin"
	}

	Remove-Item Env:\GOOS
	Remove-Item Env:\GOARCH
}
elseif ($args[0] -eq "ziggy") {
	$env:GOARCH = "amd64"
	$Src = "./src/ziggy/ziggy.go"
	$OutDir = "./src/uosc/bin"

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
		upx "$OutDir/ziggy-windows.exe"
		upx "$OutDir/ziggy-linux"
		upx "$OutDir/ziggy-darwin"
	}

	Remove-Item Env:\GOOS
	Remove-Item Env:\GOARCH
}
else {
	Write-Output "Tool to build one of uosc binaries."
	Write-Output "Requirements: go, upx (if compressing)"
	Write-Output "Usage: tools/build <name> [-c]"
	Write-Output "<name> can be: tools, ziggy"
	Write-Output "-c enables binary compression (requires upx)"
}
