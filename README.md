<div align="center">
	<a href="https://user-images.githubusercontent.com/47283320/185891110-f5f8a478-3970-4a14-bbf5-b444d571e4be.webm"><img src="https://user-images.githubusercontent.com/47283320/185892154-3b0f118a-491a-4175-807e-3de05d85ec9c.png" alt="Preview screenshot"></a>
	<h1>uosc</h1>
	<p>
		Minimalist cursor proximity based UI for <a href="https://mpv.io">MPV player</a>.
	</p>
	<br>
</div>

Most notable features:

-   UI elements hide and show based on their proximity to cursor instead of every time mouse moves. This gives you 100% control over when you see the UI and when you don't. Click on the preview above to see it in action.
-   Set min timeline size to make an always visible discrete progress bar.
-   Build your own context menu with nesting support by editing your `input.conf` file.
-   UIs for:
    -   Loading external subtitles.
    -   Selecting subtitle/audio/video track.
    -   Selecting stream quality.
    -   Quick directory and playlist navigation.
-   Mouse scroll wheel does multiple things depending on what is the cursor hovering over:
    -   Timeline: seek by `timeline_step` seconds per scroll.
    -   Volume bar: change volume by `volume_step` per scroll.
    -   Speed bar: change speed by `speed_step` per scroll.
    -   Just hovering video with no UI widget below cursor: your configured wheel bindings from `input.conf`.
-   Transform chapters into timeline ranges (the red portion of the timeline in the preview).
-   And a lot of useful options and commands to bind keys to.

[Changelog](./CHANGELOG.md).

## Download

#### Latest version (recommended)

-   [`uosc.lua`](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.lua) - script file
-   [`uosc.conf`](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf) - configuration file with default values (optional)

#### Development (unstable, might be broken)

-   [`uosc.lua`](https://raw.githubusercontent.com/tomasklaen/uosc/master/scripts/uosc.lua)
-   [`uosc.conf`](https://raw.githubusercontent.com/tomasklaen/uosc/master/script-opts/uosc.conf)

## Installation

1. **uosc** is a replacement for the built in osc, so that has to be disabled first.

    In your `mpv.conf` (_List of all the possible places where configuration files can be located in is documented here: https://mpv.io/manual/master/#files_):

    ```config
    # required so that the 2 UIs don't fight each other
    osc=no
    # uosc provides its own seeking/volume indicators, so you also don't need this
    osd-bar=no
    # uosc will draw its own window controls if you disable window border
    border=no
    ```

2. Save `uosc.lua` into `scripts/` folder.

3. To configure **uosc** to your likings, create a `script-opts/uosc.conf` file, or download `uosc.conf` with all default values from one of the links above, and save into `script-opts/` folder.

4. **OPTIONAL**: If the UI feels sluggish/slow while playing video, you can remedy this a lot by placing this in your `mpv.conf`:

    ```config
    video-sync=display-resample
    ```

    Though this does come at the cost of a little bit higher CPU/GPU load.

    #### What is going on?

    **uosc** places performance as one of its top priorities, so how can the UI feel slow? Well, it really isn't, **uosc** is **fast**, it just doesn't feel like it because when video is playing, the UI rendering frequency is chained to its frame rate, so unless you are the type of person that can't see above 24fps, it _will_ feel slow, unless you tell mpv to resample the video framerate to match your display. This is mpv limitation, and not much we can do about it on our side.

## Options

All of the available **uosc** options with their default values are in the provided `uosc.conf`. Follow one of the download links to the version of this file that matches your `uosc.lua`, or just peak the [latest development version](https://github.com/tomasklaen/uosc/blob/master/uosc.conf) for a quick reference, but this might have options that are different or not available in stable release.

To change the font, **uosc** respects the mpv `osd-font` configuration. To change it, you have to declare `osd-font` in your `mpv.conf`.

## Keybindings

The only keybinds **uosc** defines by default are menu navigation keys that are active only when one of the menus (context menu, load/select subtitles,...) is active. They are:

-   `↑`, `↓`, `←`, `→` - up, down, previous menu or close, select item
-   `k`, `j`, `h`, `l` - up, down, previous menu or close, select item
-   `w`, `s`, `a`, `d` - up, down, previous menu or close, select item
-   `enter` - select item
-   `esc` - close menu
-   `wheel_up`, `wheel_down` - scroll menu
-   `pgup`, `pgdwn`, `home`, `end` - self explanatory

Click on a faded parent menu to go back to it.

Hold `shift` to activate menu item without closing the menu.

**uosc** also provides various commands with useful features to bind your preferred keys to. See [Commands](#commands) section below.

## Commands

To add a keybind to one of this commands, open your `input.conf` file and add one on a new line. The command syntax is `script-binding uosc/{command-name}`.

Example to bind the `tab` key to peek timeline:

```
tab  script-binding uosc/peek-timeline
```

Available commands:

#### `peek-timeline`

Expands the bottom timeline until pressed again, or next mouse move. Useful to check times during playback.

#### `toggle-progress`

Toggles the always visible portion of the timeline. You can look at it as switching `timeline_size_min` option between it's configured value and 0.

#### `flash-timeline`

#### `flash-top-bar`

#### `flash-volume`

#### `flash-speed`

#### `flash-pause-indicator`

#### `decide-pause-indicator`

Commands to briefly flash a specified element. You can use it in your bindings like so:

```
space        cycle pause; script-binding uosc/flash-pause-indicator
right        seek  5
left         seek -5
shift+right  seek  30; script-binding uosc/flash-timeline
shift+left   seek -30; script-binding uosc/flash-timeline
m            cycle mute; script-binding uosc/flash-volume
up           add volume  10; script-binding uosc/flash-volume
down         add volume -10; script-binding uosc/flash-volume
[            add speed -0.25; script-binding uosc/flash-speed
]            add speed  0.25; script-binding uosc/flash-speed
\            set speed 1; script-binding uosc/flash-speed
>            script-binding uosc/next; script-binding uosc/flash-top-bar; script-binding uosc/flash-timeline
<            script-binding uosc/prev; script-binding uosc/flash-top-bar; script-binding uosc/flash-timeline
```

Case for `(flash/decide)-pause-indicator`: mpv handles frame stepping forward by briefly resuming the video, which causes pause indicator to flash, and none likes that when they are trying to compare frames. The solution is to enable manual pause indicator (`pause_indicator=manual`) and use `flash-pause-indicator` (for a brief flash) or `decide-pause-indicator` (for a static indicator) as a secondary command to all bindings you wish would display it (see space binding example above).

#### `menu`

Toggles menu. Menu is empty by default and won't show up when this is pressed. Read [Menu](#menu-1) section below to find out how to fill it up with items you want there.

#### `load-subtitles`

Displays a file explorer with directory navigation to load external subtitles. Explorer only displays file types defined in `subtitle_types` option.

#### `subtitles`

Menu to select a subtitle track.

#### `audio`

Menu to select an audio track.

#### `video`

Menu to select a video track.

#### `playlist`

Playlist navigation.

#### `chapters`

Chapter navigation.

#### `stream-quality`

Switch stream quality. This is just a basic re-assignment of `ytdl-format` mpv property from predefined options (configurable with `stream_quality_options`) and video reload, there is no fetching of available formats going on.

#### `open-file`

Open file menu. Browsing starts in current file directory, or user directory when file not available.

#### `next`

Open next item in playlist, or file in current directory when there is no playlist.

#### `prev`

Open previous item in playlist, or file in current directory when there is no playlist.

#### `first`

Open first item in playlist, or file in current directory when there is no playlist.

#### `last`

Open last item in playlist, or file in current directory when there is no playlist.

#### `next-file`

Open next file in current directory. Set `directory_navigation_loops=yes` to open first file when at the end.

#### `prev-file`

Open previous file in current directory. Set `directory_navigation_loops=yes` to open last file when at the start.

#### `first-file`

Open first file in current directory.

#### `last-file`

Open last file in current directory.

#### `delete-file-next`

Delete currently playing file and start next file in playlist (if there is a playlist) or current directory.

Useful when watching episodic content.

#### `delete-file-quit`

Delete currently playing file and quit mpv.

#### `show-in-directory`

Show current file in your operating systems' file explorer.

#### `audio-device`

Switch audio output device.

#### `open-config-directory`

Open directory with `mpv.conf` in file explorer.

## Menu

**uosc** provides a way to build, display, and use your own menu. By default it displays a pre-configured menu with common actions.

To display the menu, add **uosc**'s `menu` command to a key of your choice. Example to bind it to **right click** and **menu** buttons:

```
mbtn_right  script-binding uosc/menu
menu        script-binding uosc/menu
```

To display a submenu, send a `show-submenu` message to **uosc** with first parameter specifying menu ID. Example:

```
R    script-message-to uosc show-submenu "Utils > Aspect ratio"
```

**\*menu** button is the key between **win** and **right_ctrl** buttons that none uses (might not be on your keyboard).\*

### Adding items to menu

Adding items to menu is facilitated by commenting your keybinds in `input.conf` with special comment syntax. **uosc** will than parse this file and build the context menu out of it.

#### Syntax

Comment has to be at the end of the line with the binding.

Comment has to start with `#!` (or `#menu:`).

Text after `#!` is an item title.

Title can be split with `>` to define nested menus. There is no limit on nesting.

Use `#` instead of a key if you don't necessarily want to bind a key to a command, but still want it in the menu.

If multiple menu items with the same command are defined, **uosc** will concatenate them into one item and just display all available shortcuts as that items' hint, while using the title of the first defined item.

Menu items are displayed in the order they are defined in `input.conf` file.

The command `ignore` does not result in a menu item, however all the folders leading up to it will still be created.
This allows more flexible structuring of the `input.conf` file.

#### Examples

Adds a menu item to load subtitles:

```
alt+s  script-binding uosc/load-subtitles  #! Load subtitles
```

Adds a stay-on-top toggle with no keybind:

```
#  cycle ontop  #! Toggle on-top
```

Define and display multiple shortcuts in single items' menu hint (items with same command get concatenated):

```
esc  quit  #! Quit
q    quit  #!
```

Define a folder without defining any of its contents:

```
#  ignore  #! Folder title >
```

Example context menu:

This is the default pre-configured menu if none is defined in your `input.conf`, but with added shortcuts.

```
menu        script-binding uosc/menu
mbtn_right  script-binding uosc/menu
o           script-binding uosc/open-file          #! Open file
P           script-binding uosc/playlist           #! Playlist
C           script-binding uosc/chapters           #! Chapters
S           script-binding uosc/subtitles          #! Subtitle tracks
A           script-binding uosc/audio              #! Audio tracks
q           script-binding uosc/stream-quality     #! Stream quality
>           script-binding uosc/next               #! Navigation > Next
<           script-binding uosc/prev               #! Navigation > Prev
alt+>       script-binding uosc/delete-file-next   #! Navigation > Delete file & Next
alt+<       script-binding uosc/delete-file-prev   #! Navigation > Delete file & Prev
alt+esc     script-binding uosc/delete-file-quit   #! Navigation > Delete file & Quit
alt+s       script-binding uosc/load-subtitles     #! Utils > Load subtitles
#           set video-aspect-override "-1"         #! Utils > Aspect ratio > Default
#           set video-aspect-override "16:9"       #! Utils > Aspect ratio > 16:9
#           set video-aspect-override "4:3"        #! Utils > Aspect ratio > 4:3
#           set video-aspect-override "2.35:1"     #! Utils > Aspect ratio > 2.35:1
#           script-binding uosc/audio-device       #! Utils > Audio devices
ctrl+s      async screenshot                       #! Utils > Screenshot
O           script-binding uosc/show-in-directory  #! Utils > Show in directory
#           script-binding uosc/open-config-directory #! Utils > Open config directory
esc         quit #! Quit
```

To see all the commands you can bind keys or menu items to, refer to [mpv's list of input commands documentation](https://mpv.io/manual/master/#list-of-input-commands).

## Message handlers

**uosc** listens on some messages that can be sent with `script-message-to uosc` command. Example:

```
R    script-message-to uosc show-submenu "Utils > Aspect ratio"
```

### `get-version <script_id>`

Tells uosc to send it's version to `<script_id>` script. Useful if you want to detect that uosc is installed. Example:

```lua
-- Register response handler
mp.register_script_message('uosc-version', function(version)
	print('uosc version', version)
end)

-- Ask for version
mp.commandv('script-message-to', 'uosc', 'get-version', mp.get_script_name())
```

### `show-submenu <menu_id>`

Opens one of the submenus defined in `input.conf` (read on how to build those in the Menu documentation above).

Parameters

##### `<menu_id>`

ID (title) of the submenu, including `>` subsections as defined in `input.conf`. It has to be match the title exactly.

### `show-menu <menu_json>`

A message other scripts can send to display a uosc menu serialized as JSON.

Menu data structure:

```
Menu {
    type: string | nil;
    title: string | nil;
    selected_index: number | nil;
    active_index: number | nil;
    items: Item[];
}

Submenu {
    title: string | nil;
    items: Item[];
}

Item = Command | Submenu;

Command {
    title: string | nil;
    hint: string | nil;
    value: string | string[];
}
```

When command value is a string, it'll be passed to `mp.command(value)`. If it's a table (array) of strings, it'll be used as `mp.commandv(table.unpack(value))`.

Menu `type` controls what happens when opening a menu when some other menu is already open. When the new menu type is different, it'll replace the currently opened menu. When it's the same, the currently open menu will simply be closed. This is used to implement toggling (open->close) of menus with the same key.

`active_index` displays the item at that index as active. For example, in subtitles menu, the currently displayed subtitles are considered _active_.

`selected_index` marks item at that index as selected - the starting position for all keyboard based navigation in the menu. It defaults to `active_index` if any, or `1` otherwise, which means in most cases you can just ignore this prop.

Example:

```lua
local utils = require('mp.utils')
local menu = {
    type = 'menu_type',
    title = 'Custom menu',
    active_index = 1,
    selected_index = 1,
    items = {
        {title = 'Foo', hint = 'foo', value = 'quit'},
        {title = 'Bar', hint = 'bar', value = 'quit'},
    }
}
local json = utils.format_json(menu)
mp.commandv('script-message-to', 'uosc', 'show-menu', json)
```
