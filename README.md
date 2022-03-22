<div align="center">
	<a href="https://darsain.github.io/uosc/preview.webm"><img src="https://darsain.github.io/uosc/preview.png"></a>
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

## Installation

**uosc** is a replacement for the built in osc, so that has to be disabled first.

_List of all the possible places the configuration files & folders below can be located at is documented here: https://mpv.io/manual/master/#files_

In your `mpv.conf`:

```config
# required so that the 2 UIs don't fight each other
osc=no
# uosc provides its own seeking/volume indicators, so you also don't need this
osd-bar=no
# uosc will draw its own window controls if you disable window border
border=no
```

Download and save [`uosc.lua`](https://raw.githubusercontent.com/darsain/uosc/master/uosc.lua) into `scripts/` folder.

To configure **uosc**, create a `script-opts/uosc.conf` file, or download [`uosc.conf`](https://raw.githubusercontent.com/darsain/uosc/master/uosc.conf) from this repository, and save into `script-opts/` folder.

## Options

All available options with their default values:

````conf
# timeline size when fully retracted, 0 will hide it completely
timeline_size_min=2
# timeline size when fully expanded, in pixels, 0 to disable
timeline_size_max=40
# same as ^ but when in fullscreen
timeline_size_min_fullscreen=0
timeline_size_max_fullscreen=60
# same thing as calling toggle-progress command once on startup
timeline_start_hidden=no
# comma separated states when timeline should always be visible. available: paused, audio
timeline_persistency=
# timeline opacity
timeline_opacity=0.8
# top border of background color to help visually separate timeline from video
timeline_border=1
# when scrolling above timeline, wheel will seek by this amount of seconds
timeline_step=5
# display seekable buffered ranges for streaming videos, syntax `color:opacity`,
# color is an BBGGRR hex code, set to `none` to disable
timeline_cached_ranges=345433:0.5
# floating number font scale adjustment
timeline_font_scale=1

# timeline chapters style: none, dots, lines, lines-top, lines-bottom
chapters=dots
chapters_opacity=0.3

# where to display volume controls: none, left, right
volume=right
volume_size=40
volume_size_fullscreen=60
volume_persistency=
volume_opacity=0.8
volume_border=1
volume_step=1
volume_font_scale=1

# playback speed widget: mouse drag or wheel to change, click to reset
speed=no
speed_size=46
speed_size_fullscreen=68
speed_persistency=
speed_opacity=1
speed_step=0.1
speed_font_scale=1

# controls all menus, such as context menu, subtitle loader/selector, etc
menu_item_height=36
menu_item_height_fullscreen=50
menu_wasd_navigation=no
menu_hjkl_navigation=no
menu_opacity=0.8
menu_font_scale=1

# menu button widget
# can be: never, bottom-bar, center
menu_button=never
menu_button_size=26
menu_button_size_fullscreen=30
menu_button_persistency=
menu_button_opacity=1
menu_button_border=1

# top bar with window controls and media title
# can be: never, no-border, always
top_bar=no-border
top_bar_size=40
top_bar_size_fullscreen=46
top_bar_persistency=
top_bar_controls=yes
top_bar_title=yes

# window border drawn in no-border mode
window_border_size=1
window_border_opacity=0.8

# pause video on clicks shorter than this number of milliseconds, 0 to disable
pause_on_click_shorter_than=0
# flash duration in milliseconds used by `flash-{element}` commands
flash_duration=1000
# distances in pixels below which elements are fully faded in/out
proximity_in=40
proximity_out=120
# BBGGRR - BLUE GREEN RED hex color codes
color_foreground=ffffff
color_foreground_text=000000
color_background=000000
color_background_text=ffffff
# use bold font weight throughout the whole UI
font_bold=no
# show total time instead of time remaining
total_time=no
# hide UI when mpv autohides the cursor
autohide=no
# can be: none, flash, static, manual (controlled by flash-pause-indicator and decide-pause-indicator commands)
pause_indicator=flash
# screen dim when stuff like menu is open, 0 to disable
curtain_opacity=0.5
# sizes to list in stream quality menu
stream_quality_options=4320,2160,1440,1080,720,480,360,240,144
# load first file when calling next on a last file in a directory and vice versa
directory_navigation_loops=no
# file types to look for when navigating media files
media_types=3gp,avi,bmp,flac,flv,gif,h264,h265,jpeg,jpg,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv
# file types to look for when loading external subtitles
subtitle_types=aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt
# used to approximate text width
# if you are using some wide font and see a lot of right side clipping in menus,
# try bumping this up
font_height_to_letter_width_ratio=0.5

# `chapter_ranges` lets you transform chapter indicators into range indicators.
#
# Chapter range definition syntax:
# ```
# start_pattern<color:opacity>end_pattern
# ```
#
# Multiple start and end patterns can be defined by separating them with `|`:
# ```
# p1|pN<color:opacity>p1|pN
# ```
#
# Multiple chapter ranges can be defined by separating them with comma:
#
# chapter_ranges=range1,rangeN
#
# One of `start_pattern`s can be a custom keyword `{bof}` that will match
# beginning of file when it makes sense.
#
# One of `end_pattern`s can be a custom keyword `{eof}` that will match end of
# file when it makes sense.
#
# Patterns are lua patterns (http://lua-users.org/wiki/PatternsTutorial).
# They only need to occur in a title, not match it completely.
# Matching is case insensitive.
#
# `color` is a `bbggrr` hexadecimal color code.
# `opacity` is a float number from 0 to 1.
#
# Examples:
#
# Display anime openings and endings as ranges:
# ```
# chapter_ranges=^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}
# ```
#
# Display skippable youtube video sponsor blocks from https://github.com/po5/mpv_sponsorblock
# ```
# chapter_ranges=sponsor start<3535a5:.5>sponsor end, segment start<3535a5:0.5>segment end
# ```
chapter_ranges=^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}, sponsor start<3535a5:.5>sponsor end, segment start<3535a5:0.5>segment end
````

**uosc** respects `osd-font` option, so to change the font you want it to use, you have to change `osd-font` in `mpv.conf`.

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

#### `open-config-directory`

Open directory with `mpv.conf` in file explorer.

## Menu

**uosc** provides a way to build, display, and use your own menu. By default the menu is empty and won't show up.

To display the menu, add **uosc**'s `menu` command to a key of your choice. Example to bind it to **right click** and **menu** buttons:

```
mbtn_right  script-binding uosc/menu
menu        script-binding uosc/menu
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

Suggested minimal context menu setup to start with:

```
menu        script-binding uosc/menu
mbtn_right  script-binding uosc/menu
o           script-binding uosc/open-file          #! Open file
alt+s       script-binding uosc/load-subtitles     #! Load subtitles
S           script-binding uosc/subtitles          #! Select subtitles
A           script-binding uosc/audio              #! Select audio
ctrl+s      async screenshot                       #! Utils > Screenshot
P           script-binding uosc/playlist           #! Utils > Playlist
C           script-binding uosc/chapters           #! Utils > Chapters
#           script-binding uosc/open-config-directory #! Utils > Open config directory
#           set video-aspect-override "-1"         #! Aspect ratio > Default
#           set video-aspect-override "16:9"       #! Aspect ratio > 16:9
#           set video-aspect-override "4:3"        #! Aspect ratio > 4:3
#           set video-aspect-override "2.35:1"     #! Aspect ratio > 2.35:1
O           script-binding uosc/show-in-directory  #! Show in directory
esc         quit #! Quit
q           quit #!
```

To see all the commands you can bind keys or menu items to, refer to [mpv's list of input commands documentation](https://mpv.io/manual/master/#list-of-input-commands).

## Tips

**uosc** places performance as one of the top priorities, so why does the UI feels a bit sluggish/slow/laggy (e.g. seeking indicator lags a bit behind cursor)? Well, it really isn't, **uosc** is **fast**, it just doesn't feel like it because when video is playing, the UI rendering frequency is chained to its frame rate, so unless you are the type of person that can't see above 24fps, it _does_ feel sluggish. This is an mpv limitation and I can't do anything about it :(

You can test the smoother operation by pausing the video and then using the UI, which will make it render closer to your display refresh rate.

You can remedy this a tiny bit by enabling interpolation. Add this to your `mpv.conf` file:

```
interpolation=yes
video-sync=display-resample
```

Though it does come at the cost of a higher CPU/GPU load.
