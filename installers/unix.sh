#!/bin/bash
zip_url=https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip
conf_url=https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf
data_dir="${XDG_CONFIG_HOME:-~/.config}/mpv"
zip_file=/tmp/uosc.zip

# Exit immediately if a command exits with a non-zero status
set -e

cleanup() {
	echo "Deleting: $zip_file"
	rm -f $zip_file
}

abort() {
	cleanup
	printf "%s\n" "$@" >&2
	exit 1
}

# Check OS
OS="$(uname)"
if [ "${OS}" == "Linux" ]; then
	data_dir="${XDG_CONFIG_HOME:-~/.config}/mpv"
elif [ "${OS}" == "Darwin" ]; then
	data_dir=~/Library/Preferences/mpv
else
	abort "This install script works only on linux and macOS."
fi

# Remove old and deprecated folders & files
echo "Deleting old and deprecated uosc files and directories."
rm -rf "$data_dir/scripts/uosc_shared"
rm -rf "$data_dir/scripts/uosc"
rm -f "$data_dir/scripts/uosc.lua"

# Install new version
echo "Downloading: $zip_url"
curl -o $zip_file $zip_url
echo "Extracting: $zip_file"
unzip -od $data_dir $zip_file
cleanup

# Download default config if one doesn't exist yet
scriptopts_dir="$data_dir/script-opts"
conf_file="$scriptopts_dir/uosc.conf"
if [ ! -f "$conf_file" ]; then
	echo "Config not found."
	mkdir -pv $scriptopts_dir
	echo "Downloading: $conf_url"
	curl -o $conf_file $conf_url
fi

echo "uosc has been installed."
