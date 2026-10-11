#!/bin/bash

IMAGE="$HOME/Documents/Wallpaper/wallhaven-l82mz2_3840x2160.png"                        # <- your static image
VIDEO_PLUGIN="luisbocanegra.smart.video.wallpaper.reborn"   # <- your video plugin ID
QDBUS=qdbus6                                                # use qdbus on Plasma 5

# Find the AC adapter state file
AC=$(ls /sys/class/power_supply/*/online 2>/dev/null | grep -Ei 'AC|ADP' | head -n1)

set_video() {
  $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var ds = desktops();
    for (var i = 0; i < ds.length; i++) {
      ds[i].wallpaperPlugin = '$VIDEO_PLUGIN';
    }"
}

set_image() {
  $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var ds = desktops();
    for (var i = 0; i < ds.length; i++) {
      var d = ds[i];
      d.wallpaperPlugin = 'org.kde.image';
      d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
      d.writeConfig('Image', 'file://$IMAGE');
      d.reloadConfig();
    }"
}

last=""
while true; do
  state=$(cat "$AC")
  if [ "$state" != "$last" ]; then
    if [ "$state" = "1" ]; then set_video; else set_image; fi
    last="$state"
  fi
  sleep 3
done
