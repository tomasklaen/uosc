<div align="center">
	<h1>uosc</h1>
	<p>
		Feature-rich minimalist proximity-based UI for <a href="https://mpv.io">MPV player</a>.
	</p>
	<br/>
	<a href="https://user-images.githubusercontent.com/47283320/195073006-bfa72bcc-89d2-4dc7-b8dc-f3c13273910c.webm"><img src="https://user-images.githubusercontent.com/47283320/195072935-44d591d9-00bb-4a55-8795-9cf81f65d397.png" alt="Preview screenshot"></a>
</div>

Most notable features:

-   UI elements hide and show based on their proximity to cursor instead of every time mouse moves. This gives you 100% control over when you see the UI and when you don't. Click on the preview above to see it in action.
-   Set min timeline size to make an always visible discrete progress bar.
-   Build your own context menu with nesting support by editing your `input.conf` file.
-   Configurable controls bar.
-   Fast and efficient thumbnails with [thumbfast](https://github.com/po5/thumbfast) integration.
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

[Changelog](https://github.com/tomasklaen/uosc/releases).

## Download

-   [`uosc.zip`](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip) - main archive with script and its requirements
-   [`uosc.conf`](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf) - configuration file with default values and documentation

## Installation

1. Extract `uosc.zip` into your mpv config directory.

    _List of all the possible places where it can be located is documented here: https://mpv.io/manual/master/#files_

    On Linux and macOS these terminal commands can be used to install or update uosc and thumbfast (if wget and unzip are installed):

    ```sh
    mkdir -pv ~/.config/mpv/script-opts/
    rm -rf ~/.config/mpv/scripts/uosc_shared
    wget -P /tmp/ https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip
    unzip -od ~/.config/mpv/ /tmp/uosc.zip
    rm -fv /tmp/uosc.zip
    wget -NP ~/.config/mpv/scripts/ https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua
    ```

2. **uosc** is a replacement for the built in osc, so that has to be disabled first.

    In your `mpv.conf` (file that should already exist in your mpv directory, if not, create it):

    ```config
    # required so that the 2 UIs don't fight each other
    osc=no
    # uosc provides its own seeking/volume indicators, so you also don't need this
    osd-bar=no
    # uosc will draw its own window controls if you disable window border
    border=no
    ```

3. To configure **uosc**, create a `script-opts/uosc.conf` file, or download `uosc.conf` with all default values from the link above, and save into `script-opts/` folder.

4. **OPTIONAL**: To have thumbnails in timeline, install [thumbfast](https://github.com/po5/thumbfast). That's it, no other step necessary, **uosc** integrates with it seamlessly.

5. **OPTIONAL**: If the UI feels sluggish/slow while playing video, you can remedy this a lot by placing this in your `mpv.conf`:

    ```config
    video-sync=display-resample
    ```

    Though this does come at the cost of a little bit higher CPU/GPU load.

    #### What is going on?

    **uosc** places performance as one of its top priorities, so how can the UI feel slow? Well, it really isn't, **uosc** is **fast**, it just doesn't feel like it because when video is playing, the UI rendering frequency is chained to its frame rate, so unless you are the type of person that can't see above 24fps, it _will_ feel slow, unless you tell mpv to resample the video framerate to match your display. This is mpv limitation, and not much we can do about it on our side.

## Options

All of the available **uosc** options with their default values and documentation are in the provided `uosc.conf` file.

To change the font, **uosc** respects the mpv's `osd-font` configuration.

## Navigation

These bindings are active when any **uosc** menu is open (main menu, playlist, load/select subtitles,...):

-   `up`, `down` - select previous/next item
-   `left`, `right` - back to parent menu or close, activate item
-   `enter` - activate item
-   `esc` - close menu
-   `wheel_up`, `wheel_down` - scroll menu
-   `pgup`, `pgdwn`, `home`, `end` - self explanatory
-   `ctrl+up/down` - move selected item in menus that support it (playlist)
-   `del` - delete selected item in menus that support it (playlist)
-   `shift+enter`, `shift+right` - activate item without closing the menu
-   `ctrl+enter`, `ctrl+click` - force activate an item, even if it's a submenu. In practical terms: activates a directory instead of navigation to its contents.

Click on a faded parent menu to go back to it.

## Commands

**uosc** provides various commands with useful features to bind your preferred keys to. These are all unbound by default.

To add a keybind to one of this commands, open your `input.conf` file and add one on a new line. The command syntax is `script-binding uosc/{command-name}`.

Example to bind the `tab` key to peek timeline:

```
tab  script-binding uosc/toggle-ui
```

Available commands:

#### `toggle-ui`

Makes the whole UI visible until you call this command again. Useful for peeking remaining time and such while watching.

There's also a `toggle-elements <ids>` message you can send to toggle one or more specific elements by specifying their names separated by comma:

```
script-message-to uosc toggle-elements timeline,speed
```

Available element IDs: `timeline`, `controls`, `volume`, `top_bar`, `speed`

Under the hood, `toggle-ui` is using `toggle-elements`, and that is in turn using the `set-min-visibility <visibility> [<ids>]` message. `<visibility>` is a `0-1` floating point. Leave out `<ids>` to set it for all elements.

#### `toggle-progress`

Toggles the always visible portion of the timeline. You can look at it as switching `timeline_size_min` option between it's configured value and 0.

#### `toggle-title`

Toggles the top bar title between main and alternative title's. This can also be done by clicking on the top bar.

Only relevant if top bar is enabled, `top_bar_alt_title` is configured, and `top_bar_alt_title_place` is `toggle`.

#### `flash-ui`

Command(s) to briefly flash the whole UI. Elements are revealed for a second and then fade away.

To flash individual elements, you can use: `flash-timeline`, `flash-top-bar`, `flash-volume`, `flash-speed`, `flash-pause-indicator`, `decide-pause-indicator`

There's also a `flash-elements <ids>` message you can use to flash one or more specific elements. Example:

```
script-message-to uosc flash-elements timeline,speed
```

Available element IDs: `timeline`, `controls`, `volume`, `top_bar`, `speed`, `pause_indicator`

This is useful in combination with other commands that modify values represented by flashed elements, for example: flashing volume element when changing the volume.

You can use it in your bindings like so:

```
space        cycle pause; script-binding uosc/flash-pause-indicator
right        seek  5
left         seek -5
shift+right  seek  30; script-binding uosc/flash-timeline
shift+left   seek -30; script-binding uosc/flash-timeline
m            no-osd cycle mute; script-binding uosc/flash-volume
up           no-osd add volume  10; script-binding uosc/flash-volume
down         no-osd add volume -10; script-binding uosc/flash-volume
[            no-osd add speed -0.25; script-binding uosc/flash-speed
]            no-osd add speed  0.25; script-binding uosc/flash-speed
\            no-osd set speed 1; script-binding uosc/flash-speed
>            script-binding uosc/next; script-message-to uosc flash-elements top_bar,timeline
<            script-binding uosc/prev; script-message-to uosc flash-elements top_bar,timeline
```

Case for `(flash/decide)-pause-indicator`: mpv handles frame stepping forward by briefly resuming the video, which causes pause indicator to flash, and none likes that when they are trying to compare frames. The solution is to enable manual pause indicator (`pause_indicator=manual`) and use `flash-pause-indicator` (for a brief flash) or `decide-pause-indicator` (for a static indicator) as a secondary command to appropriate bindings.

#### `menu`

Toggles default menu. Read [Menu](#menu-1) section below to find out how to fill it up with items you want there.

Note: there's also a `menu-blurred` command that opens a menu without pre-selecting the 1st item, suitable for commands triggered with a mouse, such as control bar buttons.

#### `subtitles`, `audio`, `video`

Menus to select a track of a requested type.

#### `load-subtitles`, `load-audio`, `load-video`

Displays a file explorer with directory navigation to load a requested track type.

For subtitles, the explorer only displays file types defined in `subtitle_types` option. For audio and video, the ones defined in `video_types` and `audio_types` are displayed.

#### `playlist`

Playlist navigation.

#### `chapters`

Chapter navigation.

#### `editions`

Editions menu. Editions are different video cuts available in some mkv files.

#### `stream-quality`

Switch stream quality. This is just a basic re-assignment of `ytdl-format` mpv property from predefined options (configurable with `stream_quality_options`) and video reload, there is no fetching of available formats going on.

#### `open-file`

Open file menu. Browsing starts in current file directory, or user directory when file not available. The explorer only displays file types defined in the `video_types`, `audio_types`, and `image_types` options.

You can use `ctrl+enter` or `ctrl+click` to load the whole directory in mpv instead of navigating its contents.

#### `items`

Opens `playlist` menu when playlist exists, or `open-file` menu otherwise.

#### `next`, `prev`

Open next/previous item in playlist, or file in current directory when there is no playlist. Enable `loop-playlist` to loop around.

#### `first`, `last`

Open first/last item in playlist, or file in current directory when there is no playlist.

#### `next-file`, `prev-file`

Open next/prev file in current directory. Enable `loop-playlist` to loop around

#### `first-file`, `last-file`

Open first/last file in current directory.

#### `shuffle`

Toggle uosc's playlist/directory shuffle mode on or off.

This simply makes the next selected playlist or directory item be random, like the shuffle function of most other players. This does not modify the actual playlist in any way, in contrast to the mpv built-in command `playlist-shuffle`.

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

Note: The **menu** key is the one nobody uses between the **win** and **right_ctrl** keys (it might not be on your keyboard).

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

This is the default pre-configured menu if none is defined in your `input.conf`, but with added shortcuts. To both pause & move the window with left mouse button, so that you can have the menu on the right one, enable `click_threshold` in `uosc.conf` (see default `uosc.conf` for example/docs).

```
menu        script-binding uosc/menu
mbtn_right  script-binding uosc/menu
s           script-binding uosc/subtitles          #! Subtitles
a           script-binding uosc/audio              #! Audio tracks
q           script-binding uosc/stream-quality     #! Stream quality
p           script-binding uosc/items              #! Playlist
c           script-binding uosc/chapters           #! Chapters
>           script-binding uosc/next               #! Navigation > Next
<           script-binding uosc/prev               #! Navigation > Prev
alt+>       script-binding uosc/delete-file-next   #! Navigation > Delete file & Next
alt+<       script-binding uosc/delete-file-prev   #! Navigation > Delete file & Prev
alt+esc     script-binding uosc/delete-file-quit   #! Navigation > Delete file & Quit
o           script-binding uosc/open-file          #! Navigation > Open file
#           set video-aspect-override "-1"         #! Utils > Aspect ratio > Default
#           set video-aspect-override "16:9"       #! Utils > Aspect ratio > 16:9
#           set video-aspect-override "4:3"        #! Utils > Aspect ratio > 4:3
#           set video-aspect-override "2.35:1"     #! Utils > Aspect ratio > 2.35:1
#           script-binding uosc/audio-device       #! Utils > Audio devices
#           script-binding uosc/editions           #! Utils > Editions
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

### `show-submenu <menu_id>`, `show-submenu-blurred <menu_id>`

Opens one of the submenus defined in `input.conf` (read on how to build those in the Menu documentation above). To prevent 1st item being preselected, use `show-submenu-blurred` instead.

Parameters

##### `<menu_id>`

ID (title) of the submenu, including `>` subsections as defined in `input.conf`. It has to be match the title exactly.

### `open-menu <menu_json> [submenu_id]`

A message other scripts can send to open a uosc menu serialized as JSON. You can optionally pass a `submenu_id` to pre-open a submenu. The ID is the submenu title chain leading to the submenu concatenated with `>`, for example `Tools > Aspect ratio`.

Menu data structure:

```
Menu {
  type?: string;
  title?: string;
  items: Item[];
  selected_index?: integer;
  keep_open?: boolean;
  on_close: string | string[];
}

Item = Command | Submenu;

Submenu {
  title?: string;
  hint?: string;
  items: Item[];
  keep_open?: boolean;
}

Command {
  title?: string;
  hint?: string;
  icon?: string;
  value: string | string[];
  bold?: boolean;
  italic?: boolean;
  align?: 'left'|'center'|'right';
  selectable?: boolean;
  muted?: boolean;
  active?: integer;
  keep_open?: boolean;
}
```

When `Command.value` is a string, it'll be passed to `mp.command(value)`. If it's a table (array) of strings, it'll be used as `mp.commandv(table.unpack(value))`. The same goes for `Menu.on_close`.

`Menu.type` controls what happens when opening a menu when some other menu is already open. When the new menu type is different, it'll replace the currently opened menu. When it's the same, the currently open menu will simply be closed. This is used to implement toggling of menus with the same type.

`item.icon` property accepts icon names. You can pick one from here: [Google Material Icons](https://fonts.google.com/icons?selected=Material+Icons)\
There is also a special icon name `spinner` which will display a rotating spinner. Along with a no-op command on an item and `keep_open=true`, this can be used to display placeholder menus/items that are still loading.

When `keep_open` is `true`, activating the item will not close the menu. This property can be defined on both menus and items, and is inherited from parent to child if child doesn't overwrite it.

It's usually not necessary to define `selected_index` as it'll default to the first `active` item, or 1st item in the list.

Example:

```lua
local utils = require('mp.utils')
local menu = {
  type = 'menu_type',
  title = 'Custom menu',
  items = {
    {title = 'Foo', hint = 'foo', value = 'quit'},
    {title = 'Bar', hint = 'bar', value = 'quit', active = true},
  }
}
local json = utils.format_json(menu)
mp.commandv('script-message-to', 'uosc', 'open-menu', json)
```

### `update-menu <menu_json>`

Updates currently opened menu with the same `type`. If the menu isn't open, it will be opened.

The difference between this and `open-menu` is that if the same type menu is already open, `open-menu` will close it (facilitating menu toggling with the same key/command), while `update-menu` will update it's data.

`update-menu`, along with `{menu/item}.keep_open` property and `item.command` that sends a message back can be used to create a self updating menu with some limited UI. Example:

```lua
local utils = require('mp.utils')
local script_name = mp.get_script_name()
local state = {
  checkbox = 'no',
  radio = 'bar'
}

function command(str)
  return string.format('script-message-to %s %s', script_name, str)
end

function create_menu_data()
  return {
    type = 'test_menu',
    title = 'Test menu',
    keep_open = true,
    items = {
      {
        title = 'Checkbox',
        icon = state.checkbox == 'yes' and 'check_box' or 'check_box_outline_blank',
        value = command('set-state checkbox ' .. (state.checkbox == 'yes' and 'no' or 'yes'))
      },
      {
        title = 'Radio',
        hint = state.radio,
        items = {
          {
            title = 'Foo',
            icon = state.radio == 'foo' and 'radio_button_checked' or 'radio_button_unchecked',
            value = command('set-state radio foo')
          },
          {
            title = 'Bar',
            icon = state.radio == 'bar' and 'radio_button_checked' or 'radio_button_unchecked',
            value = command('set-state radio bar')
          },
          {
            title = 'Baz',
            icon = state.radio == 'baz' and 'radio_button_checked' or 'radio_button_unchecked',
            value = command('set-state radio baz')
          },
        },
      },
      {
        title = 'Submit',
        icon = 'check',
        value = command('submit'),
        keep_open = false
      },
    }
  }
end

mp.add_forced_key_binding('t', 'test_menu', function()
  local json = utils.format_json(create_menu_data())
  mp.commandv('script-message-to', 'uosc', 'open-menu', json)
end)

mp.register_script_message('set-state', function(prop, value)
  state[prop] = value
  -- Update currently opened menu
  local json = utils.format_json(create_menu_data())
  mp.commandv('script-message-to', 'uosc', 'update-menu', json)
end)

mp.register_script_message('submit', function(prop, value)
  -- Do something with state
end)
```

### `set <prop> <value>`

Tell **uosc** to set an external property to this value. Currently, this is only used to set/display control button active state and badges:

In your script, set the value of `foo` to `1`.

```lua
mp.commandv('script-message-to', 'uosc', 'set', 'foo', 1)
```

`foo` can now be used as a `toggle` or `cycle` property by specifying its owner with a `@{script_name}` suffix:

```
toggle:icon_name:foo@script_name
cycle:icon_name:foo@script_name:no/yes!
```

If user clicks this `toggle` or `cycle` button, uosc will send a `set` message back to the script owner. You can then listen to this message, do what you need with the new value, and update uosc state accordingly:

```lua
-- Send initial value so that the button has a correct active state
mp.commandv('script-message-to', 'uosc', 'set', 'foo', 'yes')
-- Listen for changes coming from `toggle` or `cycle` button
mp.register_script_message('set', function(prop, value)
    -- ... do something with `value`
    -- Update uosc external prop
    mp.commandv('script-message-to', 'uosc', 'set', 'foo', value)
end)
```

External properties can also be used as control button badges:

```
controls=command:icon_name:command_name#foo@script_name?My foo button
```

### `overwrite-binding <name> <command>`

Allows a overwriting handling of uosc built in bindings. Useful for 3rd party scripts that specialize in a specific domain to replace built in menus or behaviors provided by existing bindings.

Example that reroutes uosc's basic stream quality menu to [christoph-heinrich/mpv-quality-menu](https://github.com/christoph-heinrich/mpv-quality-menu):

```lua
mp.commandv('script-message-to', 'uosc', 'overwrite-binding', 'stream-quality', 'script-binding quality_menu/video_formats_toggle')
```

To cancel the overwrite and return to default behavior, just omit the `<command>` parameter.

## Why _uosc_?

It stood for micro osc as it used to render just a couple rectangles before it grew to what it is today. And now it means a minimalist UI design direction where everything is out of your way until needed.
