#!/bin/bash
set -o pipefail

# ---------- settings (override with Environment= in the service) ----------
VIDEO_PLUGIN="${WALLPAPER_VIDEO_PLUGIN:-luisbocanegra.smart.video.wallpaper.reborn}"
SOURCE="${WALLPAPER_SOURCE:-any}"                      # wallhaven | konachan | any

# Several queries separated by |, one is picked at random on every fetch
WH_QUERIES="${WALLPAPER_WH_QUERIES:-anime city night|anime lonely girl|alone girl|anime night sky girl|anime rain city|anime sitting alone}"
KONA_QUERIES="${WALLPAPER_KONA_QUERIES:-night city|solo night|scenic night|rain city|solo sky}"

SAVED_DIR="${WALLPAPER_SAVED_DIR:-$HOME/Documents/Wallpaper}"       # offline fallback
CACHE_DIR="${WALLPAPER_CACHE_DIR:-$HOME/Pictures/wallpaper-fetch}"  # downloads

# Tried from highest to lowest; first tier with a result wins
RES_TIERS="${WALLPAPER_RES_TIERS:-7680x4320 5120x2880 3840x2160 2560x1440 1920x1080}"
RATIOS="${WALLPAPER_RATIOS:-16x9}"    # Wallhaven aspect ratio ("" = any)

INTERVAL=$(( ${WALLPAPER_INTERVAL_MIN:-10} * 60 ))   # new web wallpaper every N minutes
RETRY=300                    # wait 5 min after a failed fetch
CHECK_EVERY=10               # seconds between state checks
KEEP=15                      # downloads to keep (high-res files are large)
QDBUS=qdbus6
# --------------------------------------------------------------------------

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-power"
LAST_OK="$STATE_DIR/last_fetch"      # time of last successful fetch
LAST_TRY="$STATE_DIR/last_try"       # time of last attempt
LAST_IMG="$STATE_DIR/last_image"     # last web image path
mkdir -p "$STATE_DIR" "$CACHE_DIR"

AC=$(grep -l '^Mains$' /sys/class/power_supply/*/type 2>/dev/null | head -n1 | sed 's/type$/online/')
[ -z "$AC" ] && { echo "No AC adapter found" >&2; exit 1; }

log() { echo "$*" >&2; }
js()  { $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" >/dev/null; }

# ---------- internet check (local, no traffic) ----------
online() {
    if command -v nmcli >/dev/null; then
        [ "$(nmcli -t -g STATE general 2>/dev/null)" = "connected" ]
    else
        curl -fsI --max-time 5 https://wallhaven.cc >/dev/null 2>&1
    fi
}

# ---------- wallpaper setters ----------
set_video() {
    js "var ds = desktops();
        for (var i = 0; i < ds.length; i++) { ds[i].wallpaperPlugin = '$VIDEO_PLUGIN'; }"
}

set_image() {
    local img="$1"
    [ -f "$img" ] || { log "Image missing: $img"; return 1; }
    js "var ds = desktops();
        for (var i = 0; i < ds.length; i++) {
            var d = ds[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
            d.writeConfig('Image', 'file://$img');
            d.reloadConfig();
        }"
}

pick_saved() {
    find "$SAVED_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | shuf -n1
}

# ---------- fetching ----------
fetch() { curl -fsSL -A "wallpaper-power/1.0" "$@"; }

pick_query() { printf '%s' "$1" | tr '|' '\n' | shuf -n1; }

url_wallhaven() {
    local res="$1" q
    q=$(pick_query "$WH_QUERIES")
    log "Wallhaven query: $q"
    local args=(
        --data-urlencode "q=$q"
        --data-urlencode "categories=111"
        --data-urlencode "purity=100"
        --data-urlencode "atleast=$res"
        --data-urlencode "sorting=random"
    )
    [ -n "$RATIOS" ] && args+=(--data-urlencode "ratios=$RATIOS")
    fetch --max-time 15 -G "https://wallhaven.cc/api/v1/search" "${args[@]}" \
        | jq -r '.data[].path' | shuf -n1
}

url_konachan() {
    local w="${1%x*}" h="${1#*x}" q
    q=$(pick_query "$KONA_QUERIES")
    log "Konachan tags: $q"
    fetch --max-time 15 -G "https://konachan.net/post.json" \
        --data-urlencode "limit=20" \
        --data-urlencode "tags=order:random rating:safe width:>=$w height:>=$h $q" \
        | jq -r '.[].file_url' | shuf -n1
}

download() {
    local url="$1" src="$2" ext tmp dest
    case "$url" in //*) url="https:$url" ;; esac
    ext="${url##*.}"; ext="${ext%%\?*}"; ext="${ext,,}"
    case "$ext" in jpg|jpeg|png|webp) ;; *) ext=jpg ;; esac
    tmp=$(mktemp "$CACHE_DIR/.dl.XXXXXX") || return 1
    if fetch --max-time 180 -o "$tmp" "$url" \
       && file -b --mime-type "$tmp" | grep -q '^image/'; then
        dest="$CACHE_DIR/$(date +%Y%m%d-%H%M%S)-$src.$ext"
        mv "$tmp" "$dest" && echo "$dest"
    else
        rm -f "$tmp"; return 1
    fi
}

# Highest resolution tier first, then each source within the tier
fetch_new() {
    local order s url img res
    if [ "$SOURCE" = "any" ]; then
        order=$(printf 'wallhaven\nkonachan\n' | shuf)
    else
        order="$SOURCE"
    fi
    for res in $RES_TIERS; do
        for s in $order; do
            url=$(url_$s "$res") || continue
            [ -n "$url" ] || continue
            if img=$(download "$url" "$s"); then
                log "Resolution tier: $res ($s)"
                echo "$img"; return 0
            fi
        done
    done
    return 1
}

cleanup_cache() {
    ls -1t "$CACHE_DIR" | tail -n +$((KEEP + 1)) | while read -r f; do
        rm -f -- "$CACHE_DIR/$f"
    done
}

# ---------- mode handlers ----------
mode=""
force=0
sleep_pid=""
trap 'force=1; [ -n "$sleep_pid" ] && kill "$sleep_pid" 2>/dev/null' USR1

do_video() {
    [ "$mode" = "video" ] && return
    log "Charger connected: video wallpaper"
    set_video
    mode="video"
}

do_offline() {
    [ "$mode" = "offline" ] && return
    local img; img=$(pick_saved)
    log "Offline: saved wallpaper ($img)"
    [ -n "$img" ] && set_image "$img"
    mode="offline"
}

do_web() {
    local now last try img prev
    now=$(date +%s)
    last=$(cat "$LAST_OK" 2>/dev/null || echo 0)
    try=$(cat "$LAST_TRY" 2>/dev/null || echo 0)
    prev=$(cat "$LAST_IMG" 2>/dev/null)

    # due for a new image (or none yet), and not retrying too fast
    if { [ $((now - last)) -ge "$INTERVAL" ] || [ ! -f "$prev" ]; } \
       && [ $((now - try)) -ge "$RETRY" ]; then
        echo "$now" > "$LAST_TRY"
        if img=$(fetch_new); then
            echo "$img" > "$LAST_IMG"; echo "$now" > "$LAST_OK"
            log "New web wallpaper: $img"
            set_image "$img"; cleanup_cache
            mode="web"; return
        fi
        log "Fetch failed"
    fi

    # entering web mode without a new image: reuse the last one, else a saved one
    if [ "$mode" != "web" ]; then
        prev=$(cat "$LAST_IMG" 2>/dev/null)
        [ -f "$prev" ] || prev=$(pick_saved)
        log "Battery + internet: showing $prev"
        [ -n "$prev" ] && set_image "$prev"
        mode="web"
    fi
}

# ---------- main loop ----------
while true; do
    if [ "$force" = "1" ]; then
        force=0
        rm -f "$LAST_OK" "$LAST_TRY"   # makes a new image due immediately
        mode=""                        # forces the handlers to re-apply
        log "Manual switch requested"
    fi

    if [ "$(cat "$AC")" = "1" ]; then
        do_video
    elif online; then
        do_web
    else
        do_offline
    fi

    if [ "$force" != "1" ]; then
        sleep "$CHECK_EVERY" &
        sleep_pid=$!
        wait "$sleep_pid"
    fi
done
