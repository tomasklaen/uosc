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