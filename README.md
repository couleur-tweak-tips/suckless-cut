> **Warning**
>
> This is not fully functional yet (e.g FFmpeg export option still missing) and still has a few rough edges

Lets you set timestamps (which get represented for you by chapters) to export your videos with FFmpeg or [Smoothie](https://github.com/couleur-tweak-tips/Smoothie)

### Keybinds

* <kbd>g</kbd> and <kbd>h</kbd> to set the start and end points of your index (will be put at your current time position in the video)
* <kbd>G</kbd> and <kbd>H</kbd> will do the same but set them at the very start of the video (00:00:00) or the very last second of the video

* <kbd>CTRL+k</kbd> toggles between TRIM and SPLIT mode:
    * SPLIT separates every single cut into separate files
    * TRIM merges and joins the multiple cuts you have per video
* <kbd>CTRL+v</kbd> toggles on/off verbose

* <kbd>CTRL+e</kbd> toggles exporting modes:
    * FFmpeg with keyframe cutting
    * [Smoothie](https://github.com/couleur-tweak-tips/Smoothie), my VapourSynth-based motion blur program
        * Default behavior when the script inits can be set in the first few lines of the lua script, when you are [installing Smoothie](https://github.com/couleur-tweak-tips/TweakList/blob/master/modules/Installers/Invoke-SmoothiePost.ps1) the default gets changed to Smoothie

* <kbd>c</kbd> and <kbd>C</kbd> lets you go down (uncapped), and up (with capitalized) your **indexes**, which is what each `start`-`end` combo is called

Or if you have the amazing [uosc](https://github.com/tomasklaen/uosc) ui installed you can press <kbd>Ctrl+t</kbd> for a beautiful index selector


![](https://media.discordapp.net/attachments/829078609465180170/1040925209240272997/image.png)

## Roadmap

* Export option to FFmpeg (Lossless-Cut style)
* Demo video

### input.conf template (set to defaults)
```yaml
# suckless-cut
g       script-binding set-start
G       script-binding set-sof
h       script-binding set-fin
H       script-binding set-eof
Ctrl+r  script-binding exportSLC
Ctrl+k  script-binding toggleSLCexportModes
Ctrl+v  script-binding toggleSLCverbose
Ctrl+g  script-binding getCurrentIndex
C       script-binding increaseIndex
c       script-binding decreaseIndex
Ctrl+p  script-binding showPoints
Ctrl+t  script-binding selectindex

# misc suckless cut
Ctrl+p  script-binding showPoints
n       script-binding createChapter
Ctrl+D  script-binding deletechapters
R       script-binding reloadTrs
```

### Acknowledgements

* @po5 for his help, check out his thumbnailer script [thumbfast](https://github.com/po5/thumbfast)
* Tomas Klaen for making [uosc](https://github.com/tomasklaen/uosc)