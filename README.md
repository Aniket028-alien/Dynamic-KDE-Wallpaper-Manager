# Dynamic KDE Wallpaper Manager

Automatically switches your KDE Plasma wallpaper based on power and network state.

| Situation | Wallpaper |
|---|---|
| Plugged in | Video wallpaper |
| On battery + internet | Highest-resolution image from Wallhaven / Konachan, new one every 3 hours |
| On battery + no internet | Random image from your saved wallpapers folder |

## Requirements
- KDE Plasma 6 (uses `qdbus6`)
- A video wallpaper plugin, e.g. Smart Video Wallpaper Reborn
- NetworkManager (`nmcli`)
- `curl`, `jq`, `file`

```bash
sudo apt install curl jq file network-manager
```

## Install
```bash
git clone git@github.com:Aniket028-alien/Dynamic-KDE-Wallpaper-Manager.git
cd Dynamic-KDE-Wallpaper-Manager

mkdir -p ~/.local/bin ~/.config/systemd/user
cp wallpaper-power.sh ~/.local/bin/ && chmod +x ~/.local/bin/wallpaper-power.sh
cp systemd/wallpaper-power.service ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now wallpaper-power.service
```

## Configure
Add `Environment=NAME=value` lines to the `[Service]` section of the service file, then run
`systemctl --user daemon-reload && systemctl --user restart wallpaper-power.service`.

| Variable | Default | Description |
|---|---|---|
| `WALLPAPER_VIDEO_PLUGIN` | `luisbocanegra.smart.video.wallpaper.reborn` | Video plugin ID |
| `WALLPAPER_SOURCE` | `any` | `wallhaven`, `konachan`, or `any` |
| `WALLPAPER_WH_QUERY` | `nature landscape` | Wallhaven search terms |
| `WALLPAPER_KONA_TAGS` | `scenic landscape` | Konachan tags (use underscores) |
| `WALLPAPER_SAVED_DIR` | `~/Documents/Wallpaper` | Offline fallback images |
| `WALLPAPER_CACHE_DIR` | `~/Pictures/wallpaper-fetch` | Downloaded images |
| `WALLPAPER_RES_TIERS` | `7680x4320 5120x2880 3840x2160 2560x1440 1920x1080` | Resolutions tried, highest first |
| `WALLPAPER_RATIOS` | `16x9` | Wallhaven aspect ratio (`""` for any) |

Only SFW content is requested from both sites.

## Logs
```bash
journalctl --user -u wallpaper-power.service -f
```

## Uninstall
```bash
systemctl --user disable --now wallpaper-power.service
rm ~/.local/bin/wallpaper-power.sh ~/.config/systemd/user/wallpaper-power.service
```
