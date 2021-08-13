# AnimatedGif

AnimatedGif is an screensaver for Mac OSX / macOS that plays animated GIFs.

It also has a background mode to let you run the gif as a desktop background (or wallpaper). The background mode can be enabled under "Screen Saver Options" in macOS.

You can either open only one single GIF file or you can choose a directory that contains more than one GIF file. In case of a selected directory the option panel of screensaver will let you choose a time between 1 and 30 minutes after which the GIF file is randomly changed.

Since 1.5.1 also animated PNG (Animated Portable Network Graphics (APNG)) are supported (starting with OSX 10.10).
<br>

## Compatibility

This project was originally (release 1.0) written with Xcode 6.2 and SDK for OSX 10.9 Mavericks. 

The release 1.4.0 was compiled with Xcode 10.1 with SDK for OSX 10.14 Mojave. It was tested successfully under Mavericks(10.9.5), El Capitan(10.11.6), High Sierra(10.13.6) and Mojave(10.14.5).

The release 1.5.3 was compiled with Xcode 10.2.1 with SDK for OSX 10.14 Mojave. It was tested successfully under Mavericks(10.9.5), High Sierra(10.13.6) and Mojave(10.14.6).

The latest release 1.5.4 was compiled with Xcode 12.5.1 with SDK for macOS 11 Big Sur. It was tested successfully under High Sierra(10.13.6), Mojave(10.14.6) and Big Sur(11.5.2).

_Note: AnimatedGif is **not working** with **Catalina(10.15)** and early versions of **Big Sur(11)** (later OS versions of Big Sur make Sandbox more open and allow selection of local user files) since screensavers are sandboxed (this means no GIF files can be selected or read from local disk and also background mode is broken), see issue <a href="https://github.com/Waitsnake/AnimatedGif/issues/57">#57</a> and <a href="https://github.com/Waitsnake/AnimatedGif/issues/63">#63</a>._

Since release 1.5.0 AnimatedGif supports Metal(API) for rendering.

When started AnimatedGif tries to initialise Metal as first choice for rendering. Only if this initialisation fails (on MacOSX versions older than El Capitan (10.11) or not supported Macs(usually Macs older as Mid 2012; except Mac Pro models from Mid 2010 with supported graphics card)) it tries to initialise OpenGL for rendering(as it was default between release 1.0 till 1.4.0).

Unfortunately the screensaver clock is not working together with background mode and will be disabled if background mode is enabled. But the clock works fine in normal screensaver mode.

Because Big Sur(11.5.2) still sandboxes screensaver the background mode is still not working and so this button will be automaticly disabled since release 1.5.4 when Big Sur(and Catalina) is detected. But background mode is still available on Mojave or earlier versions of OSX.

<br>

## Setup - Mac

1. Download and unzip the compiled release file from the releases tab: https://github.com/Waitsnake/AnimatedGif/releases/latest/
2. Double click on the extracted "AnimatedGif.saver" file. macOS will ask if you like to install the screen saver
3. Open ***System Preferences -> Desktop and Screensaver***
4. Select the AnimatedGif Screensaver
5. Click "Screen Saver Options" below the screensaver preview
6. Select your .gif file and adjust other settings to your liking
<p align="left">
<img src="readme_extra/screensaver.png?raw=true" width="500"/>
</p>
<p align="left">
<img src="readme_extra/options.png?raw=true" width="500"/>
</p>
<br>

## If there is an error message saying "[AnimatedGif.saver] can't be opened because it is from an unidentified developer"
<br>
<img src="readme_extra/can_not_open_1.png?raw=true" width="500"/>

1. Open System Preferences
2. Go to "Security & Privacy"
3. Click "Open Anyway"
<br>
<img src="readme_extra/can_not_open_2.png?raw=true" width="500"/>
4. Click "Open"
<br>
<img src="readme_extra/can_not_open_3.png?raw=true" width="500"/>
5. Choose if you like to install screensaver for actual user onyl or all users
<br>
6. Click "Install"
<br>
<img src="readme_extra/can_not_open_4.png?raw=true" width="500"/>

## Uninstall AnimatedGif

***Automatic Uninstall***
<br>
In the linked tools here are 3 different ways to uninstall AnimatedGif. Each tool do the same and what way you choose depending only on your personal preferences.

- <a href="https://github.com/Waitsnake/AnimatedGif/raw/master/tools/Uninstall_AnimatedGif.app.zip">Uninstall_AnimatedGif.app.zip</a> is an ZIP file containing an macOS application that uninstalls AnimatedGif (recommended way for unexperienced users)
- <a href="https://github.com/Waitsnake/AnimatedGif/raw/master/tools/Uninstall_AnimatedGif.scpt">Uninstall_AnimatedGif.scpt</a> is an AppleScript that uninstalls AnimatedGif
- <a href="https://github.com/Waitsnake/AnimatedGif/raw/master/tools/Uninstall_AnimatedGif.sh">Uninstall_AnimatedGif.sh</a> is an shell script that uninstalls AnimatedGif
<br>

***Manually Uninstall***
<br>
1. Open ***System Preferences -> Desktop and Screensaver***
2. Click "Screen Saver Options" and stop the background mode if it was enabled and close options.
3. Right click the AnimatedGif Screensaver and select "Delete AnimatedGif"
4. Click on "Move to Trash" to confirm
<p align="left">
<img src="readme_extra/delete1.png?raw=true" width="500"/>
</p>
<p align="left">
<img src="readme_extra/delete2.png?raw=true" width="500"/>
</p>
<br>


Copyright 2019 Marco Koehler
(under the conditions of MIT License)
