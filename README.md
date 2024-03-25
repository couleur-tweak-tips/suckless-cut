# suckless-cut

I recreated the features I liked from [losslesscut](https://github.com/mifi/lossless-cut) in the [mpv](https://mpv.io) (not [mpv.net](https://github.com/mpvnet-player/mpv.net)) video player via a lua script

<details>
<summary>Why?</summary>

LosslessCut is a great and intuitive user interface for cutting videos, but I dislike all the loading times you need to wait through at each step and much prefer a CLI / keyboard based workflow.

mpv is a much snappier video player, so I made a lua script with keybinds to gather in and out points of videos, and run an external process (smoothie or ffmpeg) to read that video and make a cut copy of them.
</details>

# Features

* supports cutting multiple segments (called 'indexes')
* entirely controllable by [keyboard](#keybinds)
* snappy, no chromium or javascript around here
* supports playlists (having multiple files open at once)
* segments are displayed by making fake chapters

![chapters](https://github.com/couleur-tweak-tips/suckless-cut/releases/download/readme-assets/chapters.webp)

# Installation

Place [`suckless-cut.lua`](https://github.com/couleur-tweak-tips/suckless-cut/releases/latest/download/suckless-cut.lua) in your mpv `scripts` folder

<details open>
<summary>What? what even is is my "scripts folder?"</summary>


### mpv config folder location

* https://mpv.io/manual/master/#files (on linux)

* https://mpv.io/manual/master/#files-on-windows

Tip: if you installed mpv on Windows with Scoop it's at `%USERPROFILE%\scoop\apps\mpv\current\portable_config`
</details>

You may also run mpv with `--script="/path/to/suckless-cut.lua"`
## Keybinds

### Setting in & out point(s)

* <kbd>g</kbd> and <kbd>h</kbd> sets <u>in</u> and <u>out</u> points at current player position

* <kbd>G</kbd> and <kbd>H</kbd> sets <u>in</u> point at `00:00:00`, and <u>out</u> the end of the video

### Rendering

* <kbd>Ctrl+r</kbd> takes your indexes and executes your default export program with them

### Navigating indexes

Each cut you make is stored in an index, which contains the `start`, `fin` (end) and file `path`

After setting a start and end point, setting another start point will automatically set it to index #2

* <kbd>c</kbd> and <kbd>C</kbd> lets you go down (uncapped), and up (with capitalized) your **indexes**, which is what each `start`-`end` combo is called

* <kbd>Ctrl-p</kbd> prints all indexes to console & OSD

* <kbd>Ctrl+t</kbd> (requires [uosc](https://github.com/tomasklaen/uosc) installed) graphical index selector

![image](https://github.com/couleur-tweak-tips/suckless-cut/releases/download/readme-assets/selector.webp)

* <kbd>K</kbd> cycles export modes, available: 
    * [smoothie](https://github.com/couleur-tweak-tips/smoothie-rs)
    * [ffmpeg](https://ffmpeg.org)

> [!WARNING]
> smoothie export don't contain audio, to circumvent this cut with ffmpeg first then run it manually through smoothie

* <kbd>k</kbd> cycles cutting modes:
    * `split` separates every single cut into separate files
    * `trim` merges and joins the multiple cuts you have per video

### Debugging

* <kbd>Ctrl+v</kbd> toggles on/off verbose

## How to cut at each keyframe (for better results while cutting with ffmpeg)

Keyframes are arbitrary timestamps in a video that are preferable to cut at, if not you may experience desync or your video not embedding.

To seek through each keyframes: move your cursor over to the seekbar and use your mouse scroll wheel on it to seek across keyframes, then set your start/end points with `g` `h` there. todo: find/add keybinds to easily do this via the keyboard


# Alternatives

* https://github.com/stax76/awesome-mpv#video-editing
* https://github.com/f0e/mpv-cut