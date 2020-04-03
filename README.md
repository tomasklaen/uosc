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

# `chapter_ranges` lets you define custom range indicators that will be parsed out from
# chapters, identified by chapter titles, and displayed in progressbar and seekbar.
# This requires that someone or something makes chapters that identify these ranges in their titles.
#
# Syntax 1: "<start-str>-<end-str>:<color>:<opacity>"
# Syntax 2: "<range-str>:<color>:<opacity>"
#
# Multiple chapter ranges can be defined by separating them with comma:
#
# chapter_ranges=<range1>,<range2>,<range3>
#
# `<start-str>`, `<end-str>`, and `<range-str>` only have to occur in a title, they don't have to match it completely.
# If only one `<range-str>` is specified, ranges will be created from consecutive pairs of this type of chapters.
#
# Example:
#
# Display skippable youtube video sponsor blocks from https://github.com/po5/mpv_sponsorblock
#
# chapter_ranges=Sponsor start-Sponsor end:968638:0.5
#
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
