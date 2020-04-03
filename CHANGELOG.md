## 1.3.0

New:
- Added `chapter_ranges` feature to display chapters that are intended to be ranges as bars instead of dots/lines. Read the docs for more details on how to use them.
	Quick example that displays skippable youtube video sponsor blocks from [](https://github.com/po5/mpv_sponsorblock):
	```conf
	chapter_ranges=Sponsor start-Sponsor end:968638:0.2
	```

## 1.2.0

New:
- Added `toggleseekbar` script binding.
- Added `autohide` option to control UI autohide when cursor autohides. Off by default.

## 1.1.0

New:
- Proximity UI elements now hide on `cursor-autohide` (mpv's cursor autohide time option).
- Added chapter indicators for both seekbar and progressbar. They can be configured with these new options:
	```conf
	# seekbar chapters indicator style: dots, lines, lines-top, lines-bottom
	# set to empty to disable
	seekbar_chapters=dots
	# seekbar chapters indicator opacity
	seekbar_chapters_opacity=0.3
	# progressbar chapters indicator style: dots, lines, lines-top, lines-bottom
	# set to empty to disable
	progressbar_chapters=dots
	# progressbar chapters indicator opacity
	progressbar_chapters_opacity=0.3
	```

Changed:
- Now renders a 1px bottom border for both bars in no-border window mode so they can be visible when window is over a light background.
- Improved formula for seekbar font size so it's more readable in thinner seekbar sizes.
- Tweaked some default option values for sizes and visibility of both bars.
- `bar_opacity` option got split up into `seekbar_opacity` and `progressbar_opacity`.
- `bar_color_foreground` renamed to `color_foreground`.
- `bar_color_background` renamed to `color_background`.

Fixed:
- Default examples as well as `uosc.conf` file were not working because comments were on the same line as option declarations, which apparently mpv can't parse. So that's fixed now.

### 1.0.5

Ensures time text seen above the cursor during seeking doesn't overflow the screen. This is a naive implementation that is only guessing the width of the text, since there is no other API to use for this.

### 1.0.4

Tweaked styling of window controls to be more visible against pure black backgrounds.

### 1.0.3

Simplified options and made them more explicit.

These options are gone:

```
progressbar=yes/no # toggle progressbar
progressbar_fullscreen=yes/no # toggle progressbar
```

Their functionality moved here:

```
progressbar_size=4             # progressbar size in pixels, 0 to disable
progressbar_size_fullscreen=4  # same as ^ but when in fullscreen
```

And you can also disable seekbar if you want:

```
seekbar_size=40            # seekbar size in pixels, 0 to disable
seekbar_size_fullscreen=40 # same as ^ but when in fullscreen
```

### 1.0.2

Fixed long window titles wrapping all over the place instead of being clipped by control buttons.

### 1.0.1

**uosc** now won't render when default osc is not disabled (`osc=no`).

# 1.0.0

Initial release.
