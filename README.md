<div align="center">
	<h1>uosc</h1>
	<p>
		Feature-rich minimalist proximity-based UI for <a href="https://mpv.io">MPV player</a>.
	</p>
	<br/>
	<a href="https://user-images.githubusercontent.com/47283320/195073006-bfa72bcc-89d2-4dc7-b8dc-f3c13273910c.webm"><img src="https://github.com/tomasklaen/uosc/assets/47283320/9f99f2ae-3b65-4935-8af3-8b80c605f022" alt="Preview screenshot"></a>
</div>

Features:

-   UI elements hide and show based on their proximity to cursor instead of every time mouse moves. This provides 100% control over when you see the UI and when you don't. Click on the preview above to see it in action.
-   When timeline is unused, it can minimize itself into a small discrete progress bar.
-   Build your own context menu with nesting support by editing your `input.conf` file.
-   Configurable controls bar.
-   Fast and efficient thumbnails with [thumbfast](https://github.com/po5/thumbfast) integration.
-   UIs for:
    -   Selecting subtitle/audio/video track.
    -   [Downloading subtitles](#download-subtitles) from [Open Subtitles](https://www.opensubtitles.com).
    -   Loading external subtitles.
    -   Selecting stream quality.
    -   Quick directory and playlist navigation.
-   All menus are instantly searchable. Just start typing.
-   Mouse scroll wheel does multiple things depending on what is the cursor hovering over:
    -   Timeline: seek by `timeline_step` seconds per scroll.
    -   Volume bar: change volume by `volume_step` per scroll.
    -   Speed bar: change speed by `speed_step` per scroll.
    -   Just hovering video with no UI widget below cursor: your configured wheel bindings from `input.conf`.
-   Right click on volume or speed elements to reset them.
-   Transform chapters into timeline ranges (the red portion of the timeline in the preview).
-   And a lot of useful options and commands to bind keys to.

[Changelog](https://github.com/tomasklaen/uosc/releases).

## Install

1. These commands will install or update **uosc** and place a default `uosc.conf` file into `script-opts` if it doesn't exist already.

    ### Windows

    _Optional, needed to run a remote script the first time if not enabled already:_

    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```

    Run:

    ```powershell
    irm https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/windows.ps1 | iex
    ```

    _**NOTE**: If this command is run in an mpv installation directory with `portable_config`, it'll install there instead of `AppData`._

    _**NOTE2**: The downloaded archive might trigger false positives in some antiviruses. This is explained in [FAQ below](#why-is-the-release-reported-as-malicious-by-some-antiviruses)._

    ### Linux & macOS

    _Requires **curl** and **unzip**._

    ```sh
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"
    ```

    On Linux, we try to detect what package manager variant of the config location you're using, with precedent being:

    ```
    ~/.var/app/io.mpv.Mpv     (flatpak)
    ~/snap/mpv
    ~/snap/mpv-wayland
    ~/.config/mpv
    ```

    To install into any of these locations, make sure the ones above it don't exist.

    ### Manual

    1. Download & extract [`uosc.zip`](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip) into your mpv config directory. (_See the [documentation of mpv config locations](https://mpv.io/manual/master/#files)._)

    2. If you don't have it already, download & extract [`uosc.conf`](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf) into `script-opts` inside your mpv config directory. It contains all of uosc options along with their default values and documentation.

2. **OPTIONAL**: `mpv.conf` tweaks to better integrate with **uosc**:

    ```config
    # uosc provides seeking & volume indicators (via flash-timeline and flash-volume commands)
    # if you decide to use them, you don't need osd-bar
    osd-bar=no

    # uosc will draw its own window controls and border if you disable window border
    border=no
    ```

3. **OPTIONAL**: To have thumbnails in timeline, install [thumbfast](https://github.com/po5/thumbfast). No other step necessary, **uosc** integrates with it seamlessly.

4. **OPTIONAL**: If the UI feels sluggish/slow while playing video, you can remedy this _a bit_ by placing this in your `mpv.conf`:

    ```config
    video-sync=display-resample
    ```

    Though this does come at the cost of a little bit higher CPU/GPU load.

    #### What is going on?

    **uosc** places performance as one of its top priorities, but it might feel a bit sluggish because during a video playback, the UI rendering frequency is chained to its frame rate. To test this, you can pause the video which will switch refresh rate to be closer or match the frequency of your monitor, and the UI should feel smoother. This is mpv limitation, and not much we can do about it on our side.

## Options

All of the available **uosc** options with their default values are documented in [`uosc.conf`](https://github.com/tomasklaen/uosc/blob/HEAD/src/uosc.conf) file ([download](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf)).

To change the font, **uosc** respects the mpv's `osd-font` configuration.

## Navigation

These bindings are active when any **uosc** menu is open (main menu, playlist, load/select subtitles,...):

-   `up`, `down` - Select previous/next item.
-   `left`, `right` - Back to parent menu or close, activate item.
-   `enter` - Activate item.
-   `esc` - Close menu.
-   `wheel_up`, `wheel_down` - Scroll menu.
-   `pgup`, `pgdwn`, `home`, `end` - Self explanatory.
-   `ctrl+f` or `\` - In case `menu_type_to_search` is disabled, these two trigger the menu search instead.
-   `ctrl+enter` - Submits a search in menus without instant search.
-   `ctrl+backspace` - Delete search query by word.
-   `shift+backspace` - Clear search query.
-   `ctrl+up/down` - Move selected item in menus that support it (playlist).
-   `del` - Delete selected item in menus that support it (playlist).
-   `shift+enter`, `shift+right` - Activate item without closing the menu.
-   `alt+enter`, `alt+click` - In file navigating menus, opens a directory in mpv instead of navigating to its contents.

Click on a faded parent menu to go back to it.

## Commands

**uosc** provides various commands with useful features to bind your preferred keys to, or populate your menu with. These are all unbound by default.

To add a keybind to one of this commands, open your `input.conf` file and add one on a new line. The command syntax is `script-binding uosc/{command-name}`.

Example to bind the `tab` key to toggle the ui visibility:

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

Toggles the timeline progress mode on/off. Progress mode is an always visible thin version of timeline with no text labels. It can be configured using the `progress*` config options.

#### `toggle-title`

Toggles the top bar title between main and alternative title's. This can also be done by clicking on the top bar.

Only relevant if top bar is enabled, `top_bar_alt_title` is configured, and `top_bar_alt_title_place` is `toggle`.

#### `flash-ui`

Command(s) to briefly flash the whole UI. Elements are revealed for a second and then fade away.

To flash individual elements, you can use: `flash-timeline`, `flash-progress`, `flash-top-bar`, `flash-volume`, `flash-speed`, `flash-pause-indicator`, `decide-pause-indicator`

There's also a `flash-elements <ids>` message you can use to flash one or more specific elements. Example:

```
script-message-to uosc flash-elements timeline,speed
```

Available element IDs: `timeline`, `progress`, `controls`, `volume`, `top_bar`, `speed`, `pause_indicator`

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

#### `download-subtitles`

A menu to search and download subtitles from [Open Subtitles](https://www.opensubtitles.com). It can also be opened by selecting the **Download** option in `subtitles` menu.

We fetch results for languages defined in *uosc**'s `languages` option, which defaults to your mpv `slang` configuration.

We also hash the current file and send the hash to Open Subtitles so you can search even with empty query and if your file is known, you'll get subtitles exactly for it.

Subtitles will be downloaded to the same directory as currently opened file, or `~~/subtitles` (folder in your mpv config directory) if playing a URL.

Current Open Subtitles limit for unauthenticated requests is **5 download per day**, but searching is unlimited. Authentication raises downloads to 10, which doesn't feel like it's worth the effort of implementing it, so currently there's no way to authenticate. 5 downloads per day seems sufficient for most use cases anyway, as if you need more, you should probably just deal with it in the browser beforehand so you don't have to fiddle with the subtitle downloading menu every time you start playing a new file.

#### `playlist`

Playlist navigation.

#### `chapters`

Chapter navigation.

#### `editions`

Editions menu. Editions are different video cuts available in some mkv files.

#### `stream-quality`

Switch stream quality. This is just a basic re-assignment of `ytdl-format` mpv property from predefined options (configurable with `stream_quality_options`) and video reload, there is no fetching of available formats going on.

#### `keybinds`

Displays a command palette menu with all key bindings defined in your `input.conf` file. Useful to check what command is bound to what shortcut, or the other way around.

#### `open-file`

Open file menu. Browsing starts in current file directory, or user directory when file not available. The explorer only displays file types defined in the `video_types`, `audio_types`, and `image_types` options.

You can use `alt+enter` or `alt+click` to load the whole directory in mpv instead of navigating its contents.
You can also use `ctrl+enter` or `ctrl+click` to append a file or directory to the playlist.

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

#### `update`

Updates uosc to the latest stable release right from the UI. Available in the "Utils" section of default menu .

Supported environments:

| Env | Works | Note |
|:---|:---:|---|
| Windows | ✔️ | _Not tested on older PowerShell versions. You might need to `Set-ExecutionPolicy` from the install instructions and install with the terminal command first._ |
| Linux (apt) | ✔️ | |
| Linux (flatpak) | ✔️ | |
| Linux (snap) | ❌ | We're not allowed to access commands like `curl` even if they're installed. (Or at least this is what I think the issue is.) |
| MacOS | ❌ | `(23) Failed writing body` error, whatever that means. |

If you know about a solution to fix self-updater for any of the currently broken environments, please make an issue/PR and share it with us!

**Note:** The terminal commands from install instructions still work fine everywhere, so you can use those to update instead.

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

Define an un-selectable, muted, and italic title item by using `#` as key, and omitting the command:

```
#    #! Title
#    #! Section > Title
```

Define a separator between previous and next items by doing the same, but using `---` as title:

```
#    #! ---
#    #! Section > ---
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
alt+i       script-binding uosc/keybinds           #! Utils > Key bindings
O           script-binding uosc/show-in-directory  #! Utils > Show in directory
#           script-binding uosc/open-config-directory #! Utils > Open config directory
#           script-binding uosc/update             #! Utils > Update uosc
esc         quit #! Quit
```

To see all the commands you can bind keys or menu items to, refer to [mpv's list of input commands documentation](https://mpv.io/manual/master/#list-of-input-commands).

## Messages

### `uosc-version <version>`

Broadcasts the uosc version during script initialization. Useful if you want to detect that uosc is installed. Example:

```lua
-- Register response handler
mp.register_script_message('uosc-version', function(version)
  print('uosc version', version)
end)
```

## Message handlers

**uosc** listens on some messages that can be sent with `script-message-to uosc` command. Example:

```
R    script-message-to uosc show-submenu "Utils > Aspect ratio"
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
  on_close?: string | string[];
  on_search?: string | string[];
  on_paste?: string | string[];
  search_style?: 'on_demand' | 'palette' | 'disabled'; // default: on_demand
  search_debounce?: 'submit' | number; // default: 0
  search_suggestion?: string;
  search_submenus?: boolean;
}

Item = Command | Submenu;

Submenu {
  title?: string;
  hint?: string;
  items: Item[];
  bold?: boolean;
  italic?: boolean;
  align?: 'left'|'center'|'right';
  muted?: boolean;
  separator?: boolean;
  keep_open?: boolean;
  on_search?: string | string[];
  on_paste?: string | string[];
  search_style?: 'on_demand' | 'palette' | 'disabled'; // default: on_demand
  search_debounce?: 'submit' | number; // default: 0
  search_suggestion?: string;
  search_submenus?: boolean;
}

Command {
  title?: string;
  hint?: string;
  icon?: string;
  value: string | string[];
  active?: integer;
  selectable?: boolean;
  bold?: boolean;
  italic?: boolean;
  align?: 'left'|'center'|'right';
  muted?: boolean;
  separator?: boolean;
  keep_open?: boolean;
}
```

When `Command.value` is a string, it'll be passed to `mp.command(value)`. If it's a table (array) of strings, it'll be used as `mp.commandv(table.unpack(value))`. The same goes for `Menu.on_close` and `on_search`. `on_search` additionally appends the current search string as the last parameter.

`Menu.type` is used to refer to this menu in `update-menu` and `close-menu`.
While the menu is open this value will be available in `user-data/uosc/menu/type` and the `shared-script-properties` entry `uosc-menu-type`. If no type was provided, those will be set to `'undefined'`.

`search_style` can be:
- `on_demand` (_default_) - Search input pops up when user starts typing, or presses `/` or `ctrl+f`, depending on user configuration. It disappears on `shift+backspace`, or when input text is cleared.
- `palette` - Search input is always visible and can't be disabled. In this mode, menu `title` is used as input placeholder when no text has been entered yet.
- `disabled` - Menu can't be searched.

`search_debounce` controls how soon the search happens after the last character was entered in milliseconds. Entering new character resets the timer. Defaults to `300`. It can also have a special value `'submit'`, which triggers a search only after `ctrl+enter` was pressed.

`search_submenus` makes uosc's internal search handler (when no `on_search` callback is defined) look into submenus as well, effectively flattening the menu for the duration of the search. This property is inherited by all submenus.

`search_suggestion` fills menu search with initial query string. Useful for example when you want to implement something like subtitle downloader, you'd set it to current file name.

`item.icon` property accepts icon names. You can pick one from here: [Google Material Icons](https://fonts.google.com/icons?icon.platform=web&icon.set=Material+Icons&icon.style=Rounded)\
There is also a special icon name `spinner` which will display a rotating spinner. Along with a no-op command on an item and `keep_open=true`, this can be used to display placeholder menus/items that are still loading.

`on_paste` is triggered when user pastes a string while menu is opened. Works the same as `on_search`.

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

Updates currently opened menu with the same `type`.

The difference between this and `open-menu` is that if the same type menu is already open, `open-menu` will reset the menu as if it was newly opened, while `update-menu` will update it's data.

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

### `close-menu [type]`

Closes the menu. If the optional parameter `type` is provided, then the menu only
closes if it matches `Menu.type` of the currently open menu.

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

### `disable-elements <script_id> <element_ids>`

Set what uosc elements your script wants to disable. To cancel or re-enable them, send the message again with an empty string in place of `element_ids`.

```lua
mp.commandv('script-message-to', 'uosc', 'disable-elements', mp.get_script_name(), 'timeline,volume')
```

Using `'user'` as `script_id` will overwrite user's `disable_elements` config. Elements will be enabled only when neither user, nor any script requested them to be disabled.

## Contributing

### Setup

If you want to test or work on something that involves ziggy (our multitool binary, currently handles searching & downloading subtitles), you first need to build it with:

```
tools/build ziggy
```

This requires [`go`](https://go.dev/dl/) to be installed and in path. If you don't want to bother with installing go, and there were no changes to ziggy, you can just use the binaries from [latest release](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip). Place folder `scripts/uosc/bin` from `uosc.zip` into `src/uosc/bin`.

### Localization

If you want to help localizing uosc by either adding a new locale or fixing one that is not up to date, start by running this while in the repository root:

```
tools/intl languagecode
```

`languagecode` can be any existing locale in `src/uosc/intl/` directory, or any [IETF language tag](https://en.wikipedia.org/wiki/IETF_language_tag). If it doesn't exist yet, the `intl` tool will create it.

This will parse the codebase for localization strings and use them to either update existing locale by removing unused and setting untranslated strings to `null`, or create a new one with all `null` strings.

You can then navigate to `src/uosc/intl/languagecode.json` and start translating.

## FAQ

#### Why is the release zip size in megabytes? Isn't this just a lua script?

We are limited in what we can do in mpv's lua scripting environment. To work around this, we include a binary tool (one for each platform), that we call to handle stuff we can't do in lua. Currently this means searching & downloading subtitles, accessing clipboard data, and in future might improve self updating, and potentially other things.

Other scripts usually choose to go the route of adding python scripts and requiring users to install the runtime. I don't like this as I want the installation process to be as seamless and as painless as possible. I also don't want to contribute to potential python version mismatch issues, because one tool depends on 2.7, other latest 3, and this one 3.9 only and no newer (real world scenario that happened to me), now have fun reconciling this. Depending on external runtimes can be a mess, and shipping a stable, tiny, and fast binary that users don't even have to know about is imo more preferable than having unstable external dependencies and additional installation steps that force everyone to install and manage hundreds of megabytes big runtimes in global `PATH`.

#### Why don't you have `uosc-{platform}.zip` releases and only include binaries for the concerned platform in each?

Then you wouldn't be able to sync your mpv config between platforms and everything _just work_.

#### Why is the release reported as malicious by some antiviruses?

Some antiviruses find our binaries suspicious due to the way go packages them. This is a known issue with all go binaries (https://go.dev/doc/faq#virus). I think the only way to solve that would be to sign them (not 100% sure though), but I'm not paying to work on free stuff. If anyone is bothered by this, and would be willing to donate a code signing certificate, let me know.

If you want to check the binaries are safe, the code is in `src/ziggy`, and you can build them yourself by running `tools/build ziggy` in the repository root.

We might eventually rewrite it in something else.

#### Why _uosc_?

It stood for micro osc as it used to render just a couple rectangles before it grew to what it is today. And now it means a minimalist UI design direction where everything is out of your way until needed.
