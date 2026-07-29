FROM ghcr.io/ptero-eggs/yolks:wine_latest

LABEL org.opencontainers.image.title="Wine Desktop" \
      org.opencontainers.image.description="Wine with an XFCE desktop, VNC, and noVNC for Pterodactyl" \
      org.opencontainers.image.source="https://git.lexian.dev/Lexian-droid/OpenClaw-pterodactyl-wine-gui-egg"

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=720 \
    DISPLAY_DEPTH=24 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    VNC_PASSWORD= \
    XVFB=0 \
    WINEPREFIX=/home/container/.wine

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xfce4 \
        xfce4-terminal \
        xvfb \
        x11vnc \
        novnc \
        websockify \
        dbus-x11 \
        xauth \
        x11-utils \
        x11-xserver-utils \
        libgl1 \
        libgl1-mesa-dri \
        libegl1 \
        mesa-utils \
        pulseaudio \
        pulseaudio-utils \
        fonts-dejavu \
        fonts-liberation \
        fonts-noto-core \
        fonts-noto-cjk \
        winbind \
        cabextract \
        unzip \
        curl \
        wget \
    && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p /home/container \
    && chown -R container:container /home/container 2>/dev/null || true

EXPOSE 5900/tcp 6080/tcp

# Keep the official tini process and inherited CMD. The wrapper prepares the
# desktop and then execs the official /entrypoint.sh command unchanged.
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash", "/entrypoint.sh"]
