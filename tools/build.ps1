# Build macros to build and compress binaries for all platforms.
# Requirements: go and upx

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

	Write-Output "Building for Windows..."
	$env:GOOS = "windows"
	go build -ldflags "-s -w" -o ./tools/intl.exe src/intl.go
	upx --brute ./tools/intl.exe

	Write-Output "Building for Linux..."
	$env:GOOS = "linux"
	go build -ldflags "-s -w" -o ./tools/intl-linux src/intl.go
	upx --brute ./tools/intl-linux

	Write-Output "Building for MacOS..."
	$env:GOOS = "darwin"
	go build -ldflags "-s -w" -o ./tools/intl-darwin src/intl.go
	upx --brute ./tools/intl-darwin

	Remove-Item Env:\GOOS
	Remove-Item Env:\GOARCH
}
else {
	Write-Output "Pass what to build. Available: intl"
}
