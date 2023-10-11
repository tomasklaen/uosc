#!/bin/bash
zip_url=https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip
conf_url=https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf
zip_file=/tmp/uosc.zip

# Exit immediately if a command exits with a non-zero status
set -e

cleanup() {
	if [ -f "$zip_file" ]; then
		echo "Deleting: $zip_file"
		rm -f $zip_file
	fi
}

abort() {
	cleanup
	echo "Error: $1"
	exit 1
}

# Check OS
OS="$(uname)"
if [ "${OS}" == "Linux" ]; then
	data_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mpv"
elif [ "${OS}" == "Darwin" ]; then
	data_dir=~/Library/Preferences/mpv
else
	abort "This install script works only on linux and macOS."
fi

# Remove old and deprecated folders & files
echo "Deleting old and deprecated uosc files and directories."
rm -rf "$data_dir/scripts/uosc_shared" || abort "Couldn't cleanup old files."
rm -rf "$data_dir/scripts/uosc" || abort "Couldn't cleanup old files."
rm -f "$data_dir/scripts/uosc.lua" || abort "Couldn't cleanup old files."

# Install new version
echo "Downloading: $zip_url"
curl -L -o $zip_file $zip_url || abort "Couldn't download the archive."
echo "Extracting: $zip_file"
unzip -od $data_dir $zip_file || abort "Couldn't extract the archive."
cleanup

# Download default config if one doesn't exist yet
scriptopts_dir="$data_dir/script-opts"
conf_file="$scriptopts_dir/uosc.conf"
if [ ! -f "$conf_file" ]; then
	echo "Config not found, downloading default one..."
	mkdir -pv $scriptopts_dir
	echo "Downloading: $conf_url"
	curl -L -o $conf_file $conf_url || abort "Couldn't download the config file, but uosc should be installed correctly."
fi

echo "uosc has been installed."
