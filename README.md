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

All available options with their default values:

```conf
# timeline size when fully retracted, 0 will hide it completely
timeline_size_min=1
# timeline size when fully expanded, in pixels, 0 to disable
timeline_size_max=40
# same as ^ but when in fullscreen
timeline_size_min_fullscreen=0
timeline_size_max_fullscreen=60
# timeline opacity
timeline_opacity=0.8
# pads the elapsed bar from top, effectively creating a top border of background
# color to help visually separate elapsed bar from video of similar color
# in no border windowed mode bottom is padded as well to separate from whatever
# is behind current window
# this might be unwanted if you are using unique/rare colors with low overlap
# chance, so you can disable it by setting to 0
timeline_padding=1

# timeline chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
chapters=dots
# timeline chapters indicator opacity
chapters_opacity=0.3

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
p  script-binding uosc/toggletimeline
```

## Commands

Available commands **uosc** listens on:

#### `toggletimeline`

Force expands/retracts the bottom timeline until next mouse move, which will reset its state.

## Tips

If the UI feels sluggish to you, it's probably because the rendering is chained to playing video frame rate.

You can test the smoother operation by pausing the video and then using the UI, which will make it render closer to display refresh rate.

To get this smoothness also while video is playing, add this to your `mpv.conf` file to enable interpolation:

```
interpolation=yes
video-sync=display-resample
```

Though it does come at the cost of a higher CPU load.
