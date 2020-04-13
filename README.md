<div align="center">
	<a href="https://darsain.github.io/uosc/preview.webm"><img src="https://darsain.github.io/uosc/preview.png" width="914" height="568"></a>
	<h1>uosc</h1>
	<p>
		Minimalist cursor proximity based UI for <a href="https://mpv.io">MPV player</a>.
	</p>
	<br>
</div>

Most notable features:

- UI elements hide and show based on their proximity to cursor instead of the annoying last mouse move time. This gives you 100% control over when you see the UI and when you don't. Click on the preview above to see it in action.
- Set min timeline size to make an always visible discrete progress bar.
- Build your own context menu with nesting support by editing your `input.conf` file.
- UIs for:
	- Loading external subtitles.
	- Selecting subtitle/audio/video track.
	- Quick directory and playlist navigation.
- Transform chapters into timeline ranges (the red portion of the timeline in the preview).
- And a lot of useful options and commands to bind keys to.

## Installation

**uosc** is a replacement for the built in osc, so that has to be disabled first.

In your `mpv.conf`:

```config
osc=no     # required so that the 2 UIs don't fight each other
border=no  # if you disable window border, uosc will draw
           # its own pretty proximity based window controls
```

Download and save [`uosc.lua`](https://raw.githubusercontent.com/darsain/uosc/master/uosc.lua) into `scripts/` folder.

To configure **uosc**, create a `script-opts/uosc.conf` file, or download [`uosc.conf`](https://raw.githubusercontent.com/darsain/uosc/master/uosc.conf) from this repository.

## Options

All available options with their default values:

```conf
# timeline size when fully retracted, 0 will hide it completely
timeline_size_min=2
# timeline size when fully expanded, in pixels, 0 to disable
timeline_size_max=40
# same as ^ but when in fullscreen
timeline_size_min_fullscreen=0
timeline_size_max_fullscreen=60
# timeline opacity
timeline_opacity=0.8
# adds a top border of background color to help visually separate elapsed bar
# from video of similar color
# in no border windowed mode bottom border is added as well to separate from
# whatever is behind the current window
# this might be unwanted if you are using unique/rare colors with low overlap
# chance, so you can disable it by setting to 0
timeline_border=1
# when video position is changed externally (e.g. hotkeys), flash the timeline
# for this amount of time, set to 0 to disable
timeline_flash_duration=300

# timeline chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
chapters=dots
# timeline chapters indicator opacity
chapters_opacity=0.3

# where to display volume controls, set to empty to disable
volume=right
# volume control horizontal size
volume_size=40
# same as ^ but when in fullscreen
volume_size_fullscreen=40
# volume controls opacity
volume_opacity=0.8
# thin border around volume slider
volume_border=1
# when clicking or dragging volume slider, volume will snap only to increments
# of this value
volume_snap_to=1
# when volume is changed externally (e.g. hotkeys), flash the volume controls
# for this amount of time, set to 0 to disable
volume_flash_duration=300

# menu
menu_item_height=40
menu_item_height_fullscreen=50
menu_opacity=0.8

# pause video on clicks shorter than this number of milliseconds
# enables you to use left mouse button for both dragging and pausing the video
# I recommend a duration of 120, leave at 0 to disable
pause_on_click_shorter_than=0
# proximity below which elements are fully faded in/expanded
proximity_min=40
# proximity above which elements are fully faded out/retracted
proximity_max=120
# BBGGRR - BLUE GREEN RED hex codes
color_foreground=ffffff
color_foreground_text=000000
color_background=000000
color_background_text=ffffff
# hide proximity based elements when mpv autohides the cursor
autohide=no
# display window title (filename) in top window controls bar in no-border mode
title=no
# load first file when calling next on last file in a directory and vice versa
directory_navigation_loops=no
# file types to display in file explorer when navigating media files
media_types=3gp,avi,bmp,flac,flv,gif,h264,h265,jpeg,jpg,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv
# file types to display in file explorer when loading external subtitles
subtitle_types=aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt
# used to approximate text width
# if you are using some wide font and see a lot of right side clipping in menus,
# try bumping this up
font_height_to_letter_width_ratio=0.5

# `chapter_ranges` lets you transform chapter indicators into range indicators
# with custom color and opacity by creating a chapter range definition that
# matches chapter titles.
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
# Display skippable youtube video sponsor blocks from https://github.com/po5/mpv_sponsorblock
# ```
# chapter_ranges=sponsor start<3535a5:0.5>sponsor end
# ```
#
# Display anime openings and endings as ranges:
# ```
# chapter_ranges=^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}
# ```
chapter_ranges=^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}, sponsor start<3535a5:.5>sponsor end
```

## Keybindings

The only keybinds **uosc** defines by default are menu navigation keys that are active only when one of the menus (context menu, load/select subtitles,...) is active. They are:

- `↑`, `↓`, `←`, `→` - up, down, previous menu or close, select item
- `k`, `j`, `h`, `l` - up, down, previous menu or close, select item
- `w`, `s`, `a`, `d` - up, down, previous menu or close, select item
- `enter` - select item
- `esc` - close menu
- `wheel_up`, `wheel_down` - scroll menu
- `pgup`, `pgdwn`, `home`, `end` - self explanatory

You can also click on a faded parent menu to go back to it.

**uosc** also provides various commands with useful features to bind your preferred keys to. See [Commands](#commands) section below.

## Commands

To add a keybind to one of this commands, open your `input.conf` file and add one on a new line. The command syntax is `script-binding uosc/{command-name}`.

Example to bind the `tab` key to flash timeline:

```
tab  script-binding uosc/flash-timeline
```

Available commands:

#### `flash-timeline`

Expands the bottom timeline until pressed again, or next mouse move. Useful to check times during playback.

#### `toggle-progress`

Toggles the always visible portion of the timeline. You can look at it as switching `timeline_size_min` option between it's configured value and 0.

#### `context-menu`

Toggles context menu. Context menu is empty by default and won't show up when this is pressed. Read [Context menu](#context-menu-1) section below to find out how to fill it up with items you want there.

#### `load-subtitles`

Displays a file explorer with directory navigation to load external subtitles. Explorer only displays file types defined in `subtitle_types` option.

#### `select-subtitles`

Menu to select a subtitle track.

#### `select-audio`

Menu to select an audio track.

#### `select-video`

Menu to select a video track.

#### `navigate-playlist`

Menu to select an item from playlist.

#### `navigate-chapters`

Menu to seek to start of a specific chapter.

#### `navigate-directory`

Menu to navigate media files in current files' directory with current file preselected.

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

Useful when watching periodic content.

#### `delete-file-quit`

Delete currently playing file and quit mpv.

#### `show-in-directory`

Show current file in your operating systems' file explorer.

## Context menu

**uosc** provides a way to build, display, and use your own context menu. Limitation is that the UI rendering API provided by mpv can only render stuff within window borders, so the menu can't float above it but needs to fit inside. This might be annoying for tiny videos but otherwise it accomplishes the same thing.

To display the menu, add **uosc**'s `context-menu` command to a key of your choice. Example to bind it to **right click** and **menu** buttons:

```
mbtn_right  script-binding uosc/context-menu
menu        script-binding uosc/context-menu
```

***menu** button is the key between **win** and **right_ctrl** buttons that none uses (might not be on your keyboard).*

### Adding items to menu

Adding items to menu is facilitated by commenting your keybinds in `input.conf` with special comment syntax. **uosc** will than parse this file and build the context menu out of it.

#### Syntax

Comment has to be at the end of the line with the binding.

Comment has to start with `#!`.

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
menu        script-binding uosc/context-menu
mbtn_right  script-binding uosc/context-menu
alt+s       script-binding uosc/load-subtitles     #! Load subtitles
S           script-binding uosc/select-subtitles   #! Select subtitles
A           script-binding uosc/select-audio       #! Select audio
ctrl+s      async screenshot                       #! Utils > Screenshot
P           script-binding uosc/navigate-playlist  #! Utils > Navigate playlist
C           script-binding uosc/navigate-chapters  #! Utils > Navigate chapters
D           script-binding uosc/navigate-directory #! Utils > Navigate directory
#           set video-aspect-override "-1"         #! Aspect ratio > Default
#           set video-aspect-override "16:9"       #! Aspect ratio > 16:9
#           set video-aspect-override "4:3"        #! Aspect ratio > 4:3
#           set video-aspect-override "2.35:1"     #! Aspect ratio > 2.35:1
o           script-binding uosc/show-in-directory  #! Show in directory
esc         quit #! Quit
q           quit #!
```

To see all the commands you can bind keys or menu items to, refer to [mpv's list of input commands documentation](https://mpv.io/manual/master/#list-of-input-commands).

## Tips

If the UI feels sluggish/slow to you, it's because when video is playing, the UI rendering frequency is chained to its frame rate, so unless you are the type of person that can't see above 24fps, it does feel sluggish.

You can test the smoother operation by pausing the video and then using the UI, which will make it render closer to your display refresh rate.

To get this smoothness also while playing a video, add this to your `mpv.conf` file to enable interpolation:

```
interpolation=yes
video-sync=display-resample
```

Though it does come at the cost of a higher CPU/GPU load.
