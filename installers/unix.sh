#!/usr/bin/env bash
zip_url=https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip
conf_url=https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf
zip_file=/tmp/uosc.zip
files=("scripts/uosc" "fonts/uosc_icons.otf" "fonts/uosc_textures.ttf" "scripts/uosc_shared" "scripts/uosc.lua")
dependencies=(curl unzip)

# Exit immediately if a command exits with a non-zero status
set -e

abort() {
	echo "Error: $1"
	echo "Aborting!"

	rm -f $zip_file || true

	echo "Deleting potentially broken install..."
	for file in ${files[@]}
	do
		rm -rf "$config_dir/$file" || true
	done

	echo "Restoring backup..."
	for file in ${files[@]}
	do
		from_path="$backup_dir/$file"
		if [[ -e "$from_path" ]]; then
			to_path="$config_dir/$file"
			to_dir="$(dirname "${to_path}")"
			mkdir -pv $to_dir || true
			mv $from_path $to_path || true
		fi
	done

	echo "Deleting backup..."
	rm -rf $backup_dir || true

	exit 1
}

# Check dependencies
missing_dependencies=()
for name in ${dependencies[@]}
do
	if [ ! -x "$(command -v $name)" ]; then
		missing_dependencies+=($name)
	fi
done
if [ ! ${#missing_dependencies[@]} -eq 0 ]; then
	echo "Missing dependencies: ${missing_dependencies[@]}"
	exit 1
fi

# Determine install directory
OS="$(uname)"
if [ ! -z "${MPV_CONFIG_DIR}" ]; then
	echo "Installing into (MPV_CONFIG_DIR):"
	config_dir="${MPV_CONFIG_DIR}"
elif [ "${OS}" == "Linux" ]; then
	# Flatpak
	if [ -d "$HOME/.var/app/io.mpv.Mpv" ]; then
		echo "Installing into (flatpak io.mpv.Mpv package):"
		config_dir="$HOME/.var/app/io.mpv.Mpv/config/mpv"

	# Snap mpv
	elif [ -d "$HOME/snap/mpv" ]; then
		echo "Installing into (snap mpv package):"
		config_dir="$HOME/snap/mpv/current/.config/mpv"

	# Snap mpv-wayland
	elif [ -d "$HOME/snap/mpv-wayland" ]; then
		echo "Installing into (snap mpv-wayland package):"
		config_dir="$HOME/snap/mpv-wayland/common/.config/mpv"

	# ~/.config
	else
		echo "Config location:"
		config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mpv"

	fi
elif [ "${OS}" == "Darwin" ]; then
	config_dir=~/.config/mpv
else
	abort "This install script works only on Linux and macOS."
fi
backup_dir="$config_dir/.uosc-backup"

echo "→ $config_dir"
mkdir -p $config_dir || abort "Couldn't create config directory."

echo "Backing up..."
rm -rf $backup_dir || abort "Couldn't cleanup backup directory."
for file in ${files[@]}
do
	from_path="$config_dir/$file"
	if [[ -e "$from_path" ]]; then
		to_path="$backup_dir/$file"
		to_dir="$(dirname "${to_path}")"
		mkdir -p $to_dir || abort "Couldn't create backup folder: $to_dir"
		mv $from_path $to_path || abort "Couldn't move '$from_path' to '$to_path'."
	fi
done

# Install new version
echo "Downloading archive..."
curl -Ls -o $zip_file $zip_url || abort "Couldn't download: $zip_url"
echo "Extracting archive..."
unzip -qod $config_dir $zip_file || abort "Couldn't extract: $zip_file"
echo "Deleting archive..."
rm -f $zip_file || echo "Couldn't delete: $zip_file"
echo "Deleting backup..."
rm -rf $backup_dir || echo "Couldn't delete: $backup_dir"

# Download default config if one doesn't exist yet
scriptopts_dir="$config_dir/script-opts"
conf_file="$scriptopts_dir/uosc.conf"
if [ ! -f "$conf_file" ]; then
	echo "Config not found, downloading default uosc.conf..."
	mkdir -p $scriptopts_dir || echo "Couldn't create: $scriptopts_dir"
	curl -Ls -o $conf_file $conf_url || echo "Couldn't download: $conf_url"
fi

echo "uosc has been installed."
