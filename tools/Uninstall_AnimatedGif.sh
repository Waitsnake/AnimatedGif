#!/bin/bash
cd
launchctl unload ~/Library/LaunchAgents/com.waitsnake.animatedgif.plist
rm ~/Library/LaunchAgents/com.waitsnake.animatedgif.plist
cd "Library/Screen Savers"
rm -rf AnimatedGif.saver
cd
cd ~/Library/Preferences/ByHost && 
rm noname.AnimatedGif.*
