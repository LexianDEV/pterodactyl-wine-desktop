# Wine Desktop

Wine Desktop extends the official Pterodactyl Wine yolk with a persistent virtual XFCE desktop. It is intended for Windows GUI applications that need a display, VNC access, or browser-based noVNC access inside a Pterodactyl or Pelican server.

## Features

- Based on `ghcr.io/ptero-eggs/yolks:wine_latest`.
- XFCE on Xvfb with configurable resolution.
- Direct VNC on TCP `5900` and browser VNC on TCP `6080`.
- Persistent Wine prefix at `/home/container/.wine`.
- PulseAudio, Mesa, fonts, winetricks, winbind, and common archive tools.
- Retains the official yolk's Steam update, Gecko/Mono, winetricks, and startup handling.

## Architecture

The image keeps the yolk's `/usr/bin/tini -g --` process and inherited command. Its entrypoint starts Xvfb, D-Bus, XFCE, x11vnc, noVNC, and the Wine prefix once, then executes the inherited `/bin/bash /entrypoint.sh`. The official entrypoint continues to expand `STARTUP`, perform optional updates and winetricks actions, and launch the application.

The Wine prefix is not deleted or rebuilt when the container restarts. Store the server data in the normal Pterodactyl volume to keep it persistent.

## Installation

Build locally:

```bash
git clone https://git.lexian.dev/Lexian-droid/OpenClaw-pterodactyl-wine-gui-egg.git WineDesktop
cd WineDesktop
docker build -t wine-desktop:latest .
```

The image exposes `5900/tcp` and `6080/tcp`. Publish those ports if running Docker directly:

```bash
docker run --rm -it -p 5900:5900 -p 6080:6080 \
  -e STARTUP='wine /home/container/application.exe' \
  wine-desktop:latest
```

For Pterodactyl or Pelican, import `egg-wine-desktop.json` into the nest, select the published image (or add your own registry tag), and create a server with the Wine Desktop Egg. Add allocations for ports 5900 and 6080 when your panel supports additional allocations.

## Startup and variables

The Egg's default startup is `wine {{SERVER_EXECUTABLE}}`, with `SERVER_EXECUTABLE` defaulting to `application.exe`. Set it to a path such as `MyApp/MyApp.exe` or use a custom startup command when needed. The underlying yolk continues to receive and evaluate its normal `STARTUP` value.

Useful variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SERVER_EXECUTABLE` | `application.exe` | Executable used by the Egg startup command |
| `DISPLAY_WIDTH` | `1280` | Virtual screen width |
| `DISPLAY_HEIGHT` | `720` | Virtual screen height |
| `WINEPREFIX` | `/home/container/.wine` | Persistent Wine prefix |
| `VNC_PASSWORD` | empty | Optional direct VNC password, up to 8 characters |
| `VNC_PORT` | `5900` | x11vnc port |
| `NOVNC_PORT` | `6080` | noVNC/websockify port |

## Connecting

Direct VNC clients connect to the server allocation on port `5900`. If `VNC_PASSWORD` is blank, VNC authentication is disabled; protect the allocation with your firewall or proxy.

Browser clients open `http://SERVER:6080/vnc.html` and connect to the displayed VNC endpoint. Use HTTPS or a reverse proxy when exposing noVNC beyond a trusted network.

## Troubleshooting

- **Black screen:** confirm ports are allocated and inspect `/tmp/wine-desktop-xfce.log` and `/tmp/wine-desktop-x11vnc.log` in the container.
- **Application does not start:** run the exact command interactively and check that the executable exists under `/home/container`; the official yolk's `STARTUP` is evaluated by Bash.
- **Prefix problems:** stop the server before changing Wine architecture or winetricks settings. Back up `.wine` before manually repairing it.
- **noVNC loads but cannot connect:** ensure both 6080 and 5900 are reachable from the container network; websockify forwards 6080 to localhost:5900.
- **No audio:** applications must support PulseAudio. The image includes the client and server packages, but application-specific audio configuration may still be required.

## FAQ

**Does this replace the official Wine yolk?** No. It uses it as the base and invokes its original entrypoint after the desktop is ready.

**Does it support Steam server updates and winetricks?** Yes. The inherited entrypoint remains responsible for those features.

**Is the desktop secure by default?** VNC is bound for container access and is intended to be protected by Pterodactyl allocations, firewall rules, or a reverse proxy. Set `VNC_PASSWORD` for direct VNC authentication and do not expose unprotected ports publicly.

**Can I use this with Pelican?** Yes. The Egg uses the modern `PTDL_v2` format and standard Docker image/startup fields.

## License

This project is licensed under the MIT License. The base Wine yolk and its components retain their own licenses.
