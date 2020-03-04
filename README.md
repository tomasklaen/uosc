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
title=no                       # display window title (filename) in no-border mode
progressbar_size=4             # progressbar size in pixels, 0 to disable
progressbar_size_fullscreen=4  # same as ^ but when in fullscreen
seekbar_size=40                # seekbar size in pixels, 0 to disable
seekbar_size_fullscreen=40     # same as ^ but when in fullscreen
min_proximity=60               # proximity below which opacity equals 1
max_proximity=120              # proximity above which opacity equals 0
bar_opacity=0.8                # max opacity of progress and seek bars
bar_color_foreground=FFFFFF    # BBGGRR - BLUE GREEN RED hex code
bar_color_background=000000    # BBGGRR - BLUE GREEN RED hex code
```

**Progressbar**: thin always visible discrete video progress bar.
**Seekbar**: thick seeking bar with times that appears when mouse is near it.

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

## Tips

If the UI feels sluggish to you, it's probably because the rendering is chained to video frame rate. Add this to your `mpv.conf` file to enable interpolation and get a more responsive UI:

```
interpolation=yes
video-sync=display-resample
```

Though it does come at the cost of a higher CPU load.