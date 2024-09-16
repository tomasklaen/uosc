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
-   Transforming chapters into timeline ranges (the red portion of the timeline in the preview).
-   A lot of useful options and commands to bind keys to.
-   [API for 3rd party scripts](https://github.com/tomasklaen/uosc/wiki) to extend, or use uosc to render their menus.

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

#### Build instructions

To build ziggy (our utility binary) yourself, run:

```
tools/build ziggy
```

Which will run the `tools/build(.ps1)` script that builds it for each platform. It requires [go](https://go.dev/) to be installed. Source code is in `src/ziggy`.

## Options

All of the available **uosc** options with their default values are documented in [`uosc.conf`](https://github.com/tomasklaen/uosc/blob/HEAD/src/uosc.conf) file ([download](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf)).

To change the font, **uosc** respects the mpv's `osd-font` configuration.

## Navigation

These bindings are active when any **uosc** menu is open (main menu, playlist, load/select subtitles,...):

-   `up`, `down` - Select previous/next item.
-   `enter` - Activate item or submenu.
-   `bs` (backspace) - Activate parent menu.
-   `esc` - Close menu.
-   `wheel_up`, `wheel_down` - Scroll menu.
-   `pgup`, `pgdwn`, `home`, `end` - Self explanatory.
-   `ctrl+f` or `\` - In case `menu_type_to_search` config option is disabled, these two trigger the menu search instead.
-   `ctrl+backspace` - Delete search query by word.
-   `shift+backspace` - Clear search query.
-   Holding `alt` while activating an item should prevent closing the menu (this is just a guideline, not all menus behave this way).

Each menu can also add its own shortcuts and bindings for special actions on items/menu, such as `del` to delete a playlist item, `ctrl+up/down/pgup/pgdwn/home/end` to move it around, etc. These are usually also exposed as item action buttons for you to find out about them that way.

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

Displays a command palette menu with all currently active keybindings (defined in your `input.conf` file, or registered by scripts). Useful to check what command is bound to what shortcut, or the other way around.

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

#### `paste`, `paste-to-open`, `paste-to-playlist`

Commands to paste path or URL in clipboard to either open immediately, or append to playlist.

`paste` will add to playlist if there's any (`playlist-count > 1`), or open immediately otherwise.

`paste-to-playlist` will also open the pasted file if mpv is idle (no file open).

Note: there are alternative ways to open stuff from clipboard without the need to bind these commands:

- When `open-file` menu is open → `ctrl+v` to open path/URL in clipboard.
- When `playlist` menu is open → `ctrl+v` to add path/URL in clipboard to playlist.
- When any track menu (`subtitles`, `audio`, `video`) is open → `ctrl+v` to add path/URL in clipboard as a new track.

#### `copy-to-clipboard`

Copy currently open path or URL to clipboard.

Additionally, you can also press `ctrl+c` to copy path of a selected item in `playlist` or all directory listing menus.

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

**uosc** listens on some messages that can be sent with `script-message-to uosc` command. Example:

```
R    script-message-to uosc show-submenu "Utils > Aspect ratio"
```

### `show-submenu <menu_id>`, `show-submenu-blurred <menu_id>`

Opens one of the submenus defined in `input.conf` (read on how to build those in the Menu documentation above). To prevent 1st item being preselected, use `show-submenu-blurred` instead.

Parameters

##### `<menu_id>`

ID (title) of the submenu, including `>` subsections as defined in `input.conf`. It has to be match the title exactly.

## Scripting API

3rd party script developers can use our messaging API to integrate with uosc, or use it to render their menus. Documentation is available in [uosc Wiki](https://github.com/tomasklaen/uosc/wiki).

## Contributing

### Localization

If you want to help localizing uosc by either adding a new locale or fixing one that is not up to date, start by running this while in the repository root:

```
tools/intl languagecode
```

`languagecode` can be any existing locale in `src/uosc/intl/` directory, or any [IETF language tag](https://en.wikipedia.org/wiki/IETF_language_tag). If it doesn't exist yet, the `intl` tool will create it.

This will parse the codebase for localization strings and use them to either update existing locale by removing unused and setting untranslated strings to `null`, or create a new one with all `null` strings.

You can then navigate to `src/uosc/intl/languagecode.json` and start translating.

### Setting up binaries

If you want to test or work on something that involves ziggy (our multitool binary, currently handles searching & downloading subtitles), you first need to build it with:

```
tools/build ziggy
```

This requires [`go`](https://go.dev/dl/) to be installed and in path. If you don't want to bother with installing go, and there were no changes to ziggy, you can just use the binaries from [latest release](https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip). Place folder `scripts/uosc/bin` from `uosc.zip` into `src/uosc/bin`.

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
