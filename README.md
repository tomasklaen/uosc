<div align="center">
	<a href="https://darsain.github.io/uosc/preview.webm"><img src="https://darsain.github.io/uosc/preview.png" width="854" height="480"></a>
	<h1>uosc</h1>
	<p>
		Minimalist proximity based UI for <a href="https://mpv.io">MPV player</a>.
	</p>
	<br>
</div>

All UI elements hide and show based on their proximity to cursor. Click on the preview above to see it in action.

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

Terminology:
- **Seekbar**: thick clickable seeking bar with elapsed/remaining times that appears when mouse is near it
- **Progressbar**: thin persistent video progress bar

All available options with their default values:

```conf
# display window title (filename) in no-border mode
title=no

# seekbar size in pixels, 0 to disable
seekbar_size=40
# same as ^ but when in fullscreen
seekbar_size_fullscreen=60
# seekbar opacity when fully visible
seekbar_opacity=0.8
# seekbar chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
seekbar_chapters=dots
# seekbar chapters indicator opacity
seekbar_chapters_opacity=0.3

# progressbar size in pixels, 0 to disable
progressbar_size=1
# same as ^ but when in fullscreen
progressbar_size_fullscreen=0
# progressbar opacity
progressbar_opacity=0.8
# progressbar chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
progressbar_chapters=dots
# progressbar chapters indicator opacity
progressbar_chapters_opacity=0.3

# proximity below which opacity equals 1
min_proximity=40
# proximity above which opacity equals 0
max_proximity=120
# BBGGRR - BLUE GREEN RED hex code
color_foreground=FFFFFF
# BBGGRR - BLUE GREEN RED hex code
color_background=000000
# hide proximity based elements when mpv autohides the cursor
autohide=no

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
# chapter_ranges=sponsor start<968638:0.5>sponsor end
# ```
#
# Display anime openings and endings as ranges:
# ```
# chapter_ranges=op<968638:0.5>.*,ed|ending<968638:0.5>.*|{eof}
# ```
chapter_ranges=
```

## Keybindings

By default, **uosc** doesn't create any keybinds, but provides commands to bind your preferred keys to. To add a keybind, open your `input.conf` file and add one on a new line.

For example, this will bind the `p` key to toggle progress bar:

```
p  script-binding uosc/toggleprogressbar
```

## Commands

Available commands **uosc** listens on:

#### `toggleprogressbar`

Toggle the thin discrete progress bar.

#### `toggleseekbar`

Toggle seekbar manually instead of moving a pointer to it. Useful to check times without touching the pointer device.

The toggled state is reset immediately on next pointer move.

## Tips

If the UI feels sluggish to you, it's probably because the rendering is chained to video frame rate. Add this to your `mpv.conf` file to enable interpolation and get a more responsive UI:

```
interpolation=yes
video-sync=display-resample
```

Though it does come at the cost of a higher CPU load.
