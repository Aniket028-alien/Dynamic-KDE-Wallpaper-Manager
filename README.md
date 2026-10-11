<<<<<<< HEAD
# Dynamic KDE Wallpaper Manager

Switches KDE Plasma wallpaper based on charger state: video wallpaper when plugged in, static image on battery.

## Requirements
- KDE Plasma 5 or 6 (uses qdbus6 / qdbus)
- A video wallpaper plugin (e.g. Smart Video Wallpaper Reborn)
- systemd user services

## Install
```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp wallpaper-power.sh ~/.local/bin/ && chmod +x ~/.local/bin/wallpaper-power.sh
cp systemd/wallpaper-power.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now wallpaper-power.service
```

## Configure
Set these environment variables in the service file:
- `WALLPAPER_IMAGE`: path to your static image
- `WALLPAPER_VIDEO_PLUGIN`: plugin ID of your video wallpaper

## Uninstall
```bash
systemctl --user disable --now wallpaper-power.service
rm ~/.local/bin/wallpaper-power.sh ~/.config/systemd/user/wallpaper-power.service
```
=======
# Dynamic-KDE-Wallpaper-Manager
Dynamic KDE Wallpaper Manager is a lightweight Bash automation project designed to make your KDE Plasma desktop smarter by dynamically switching wallpapers based on your laptop's power state.
>>>>>>> dea82bd94a0d8a4704bbdb6531f4ab4f5c73961a
