#!/usr/bin/env bash
set -Eeuo pipefail

readonly LOG_PREFIX="[wine-desktop]"

DISPLAY="${DISPLAY:-:0}"
DISPLAY_WIDTH="${DISPLAY_WIDTH:-1280}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-720}"
DISPLAY_DEPTH="${DISPLAY_DEPTH:-24}"

VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

ENABLE_VNC="${ENABLE_VNC:-true}"
ENABLE_NOVNC="${ENABLE_NOVNC:-true}"

WINEPREFIX="${WINEPREFIX:-/home/container/.wine}"

export \
    DISPLAY \
    DISPLAY_WIDTH \
    DISPLAY_HEIGHT \
    DISPLAY_DEPTH \
    VNC_PORT \
    NOVNC_PORT \
    ENABLE_VNC \
    ENABLE_NOVNC \
    WINEPREFIX

children=()

cleanup() {
    trap - EXIT INT TERM

    for pid in "${children[@]:-}"; do
        [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
    done
}

trap cleanup EXIT INT TERM

log() {
    echo "${LOG_PREFIX} $*"
}

#
# X Server
#
if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    log "Starting Xvfb on ${DISPLAY} (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH})"

    Xvfb \
        "$DISPLAY" \
        -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" \
        -ac \
        +extension GLX \
        +render \
        -noreset &

    children+=("$!")

    for _ in {1..50}; do
        if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    log "X server failed to start."
    exit 1
fi

#
# Runtime
#
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-${USER:-container}}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

#
# D-Bus
#
if command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)" || \
        log "D-Bus failed to start; continuing."
fi

#
# PulseAudio
#
if command -v pulseaudio >/dev/null 2>&1 && ! pgrep -x pulseaudio >/dev/null 2>&1; then
    log "Starting PulseAudio"

    pulseaudio \
        --system \
        --daemonize=yes \
        --disallow-exit \
        --exit-idle-time=-1 \
        >/tmp/wine-desktop-pulseaudio.log 2>&1 \
    || log "PulseAudio could not start; continuing without audio."
fi

#
# XFCE
#
if ! pgrep -x xfce4-session >/dev/null 2>&1; then
    log "Starting XFCE"

    startxfce4 >/tmp/wine-desktop-xfce.log 2>&1 &
    children+=("$!")
fi

#
# x11vnc
#
case "${ENABLE_VNC,,}" in
    true|1|yes|on)

        vnc_args=(
            -display "$DISPLAY"
            -rfbport "$VNC_PORT"
            -forever
            -shared
            -nopw
        )

        if [[ -n "${VNC_PASSWORD:-}" ]]; then
            password_file="${WINEPREFIX}/.vncpasswd"

            mkdir -p "$WINEPREFIX"

            x11vnc -storepasswd "$VNC_PASSWORD" "$password_file" >/dev/null
            chmod 600 "$password_file"

            vnc_args=(
                -display "$DISPLAY"
                -rfbport "$VNC_PORT"
                -forever
                -shared
                -rfbauth "$password_file"
            )
        fi

        log "Starting x11vnc on TCP ${VNC_PORT}"

        x11vnc "${vnc_args[@]}" \
            >/tmp/wine-desktop-x11vnc.log 2>&1 &

        children+=("$!")

        #
        # noVNC
        #
        case "${ENABLE_NOVNC,,}" in
            true|1|yes|on)

                novnc_web="/usr/share/novnc"
                [[ -d "$novnc_web" ]] || novnc_web="/usr/share/novnc/utils"

                log "Starting noVNC on TCP ${NOVNC_PORT}"

                websockify \
                    --web="$novnc_web" \
                    "${NOVNC_PORT}" \
                    "localhost:${VNC_PORT}" \
                    >/tmp/wine-desktop-novnc.log 2>&1 &

                children+=("$!")
                ;;

            *)
                log "noVNC disabled."
                ;;
        esac
        ;;

    *)
        log "VNC disabled (noVNC automatically disabled)."
        ;;
esac

#
# Wine Prefix
#
mkdir -p "$WINEPREFIX"

if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
    log "Initializing Wine prefix..."

    if ! wineboot --init; then
        log "Wine prefix initialization failed."
        log "See: /tmp/wine-desktop-wineboot.log"
        exit 1
    fi
fi

echo "STARTUP=$STARTUP"
echo "SERVER_EXECUTABLE=$SERVER_EXECUTABLE"
env | sort | grep -E 'STARTUP|SERVER|WINE'

#
# Launch the startup command from Pterodactyl
#

MODIFIED_STARTUP=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

log "Executing: ${MODIFIED_STARTUP}"

cd /home/container

exec bash -lc "${MODIFIED_STARTUP}"