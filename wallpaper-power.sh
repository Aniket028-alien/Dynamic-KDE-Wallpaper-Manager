#!/bin/bash

VIDEO_PLUGIN="${WALLPAPER_VIDEO_PLUGIN:-luisbocanegra.smart.video.wallpaper.reborn}"
QDBUS=qdbus6
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-power/image"
mkdir -p "$(dirname "$STATE_FILE")"

AC=$(grep -l '^Mains$' /sys/class/power_supply/*/type 2>/dev/null | head -n1 | sed 's/type$/online/')
[ -z "$AC" ] && { echo "No AC adapter found" >&2; exit 1; }

js() { $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

# Save the image KDE currently has configured for the image plugin
save_image() {
    local img
    img=$(js "
        var d = desktops()[0];
        d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
        print(d.readConfig('Image'));")
    [ -n "$img" ] && echo "$img" > "$STATE_FILE"
}

set_video() {
    save_image
    js "
        var ds = desktops();
        for (var i = 0; i < ds.length; i++) {
            ds[i].wallpaperPlugin = '$VIDEO_PLUGIN';
        }"
}

set_image() {
    local img
    img=$(cat "$STATE_FILE" 2>/dev/null)
    js "
        var ds = desktops();
        for (var i = 0; i < ds.length; i++) {
            var d = ds[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
            if ('$img' !== '') { d.writeConfig('Image', '$img'); }
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
