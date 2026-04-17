FROM ubuntu:24.04 AS ruos-macair

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Core system packages + MacBook Air 2012 hardware
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop (XFCE lightweight — ideal for 4-8GB RAM)
    xfce4 \
    xfce4-terminal \
    xfce4-taskmanager \
    xfce4-power-manager \
    thunar \
    lightdm \
    lightdm-gtk-greeter \
    # Network & Bluetooth
    network-manager \
    bluez \
    blueman \
    # Audio (PipeWire)
    pipewire \
    pipewire-pulse \
    wireplumber \
    pavucontrol \
    alsa-utils \
    # Intel HD Graphics 4000 (Ivy Bridge) — full GPU stack
    xserver-xorg-video-intel \
    mesa-utils \
    libgl1-mesa-dri \
    libgl1 \
    mesa-vulkan-drivers \
    intel-gpu-tools \
    vainfo \
    intel-media-va-driver \
    libva2 \
    libva-drm2 \
    libva-x11-2 \
    # MacBook Air 2012 firmware & power
    linux-firmware \
    intel-microcode \
    thermald \
    tlp \
    tlp-rdw \
    # Broadcom WiFi (BCM4360 — MacBook Air 2012)
    broadcom-sta-dkms \
    bcmwl-kernel-source \
    dkms \
    # Kernel headers for DKMS
    linux-headers-generic \
    # Touchpad
    xserver-xorg-input-libinput \
    xserver-xorg-input-synaptics \
    # Build essentials
    build-essential \
    software-properties-common \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    rsync \
    # DJ / MIDI
    libusb-1.0-0 \
    mixxx \
    # System utilities
    sudo \
    openssh-client \
    htop \
    neofetch \
    usbutils \
    pciutils \
    parted \
    dbus \
    systemd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Firefox — real .deb from Mozilla PPA (not snap)
RUN apt-get update && apt-get remove -y firefox 2>/dev/null; \
    add-apt-repository -y ppa:mozillateam/ppa && \
    printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' > /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && apt-get install -y firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node 22 for Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Tailscale
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Spotify
RUN curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | gpg --dearmor -o /usr/share/keyrings/spotify-archive-keyring.gpg && \
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes >> /usr/share/keyrings/spotify-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg allow-insecure=yes] http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list && \
    apt-get update --allow-insecure-repositories && apt-get install -y --allow-unauthenticated spotify-client && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ruOS binaries
COPY config/includes.chroot/usr/local/bin/ /usr/local/bin/

# Install-to-disk script
COPY scripts/ruos-install-to-disk /usr/local/bin/ruos-install-to-disk
RUN chmod +x /usr/local/bin/ruos-install-to-disk

# Intel HD 4000 GPU optimization — prefer hardware acceleration
RUN mkdir -p /etc/X11/xorg.conf.d && \
    printf 'Section "Device"\n  Identifier "Intel HD 4000"\n  Driver "intel"\n  Option "AccelMethod" "sna"\n  Option "TearFree" "true"\n  Option "DRI" "3"\nEndSection\n' > /etc/X11/xorg.conf.d/20-intel.conf

# MacBook Air keyboard/trackpad config
RUN printf 'options hid_apple fnmode=2\noptions hid_apple swap_opt_cmd=1\n' > /etc/modprobe.d/hid-apple.conf

# MacBook trackpad — natural scrolling, tap-to-click
RUN printf 'Section "InputClass"\n  Identifier "MacBook Trackpad"\n  MatchIsTouchpad "on"\n  Driver "libinput"\n  Option "Tapping" "on"\n  Option "NaturalScrolling" "true"\n  Option "ClickMethod" "clickfinger"\nEndSection\n' > /etc/X11/xorg.conf.d/30-touchpad.conf

# DDJ-200 MIDI permissions
RUN printf 'SUBSYSTEM=="usb", ATTR{idVendor}=="2b73", MODE="0666", GROUP="audio"\nSUBSYSTEM=="snd", KERNEL=="midi*", MODE="0666", GROUP="audio"\n' > /etc/udev/rules.d/99-dj-controller.rules

# Low-latency audio for DJ use
RUN printf '@audio - rtprio 99\n@audio - memlock unlimited\n@audio - nice -19\n' > /etc/security/limits.d/audio.conf

# TLP power config for MacBook Air 2012
RUN mkdir -p /etc/tlp.d && printf 'CPU_SCALING_GOVERNOR_ON_AC=performance\nCPU_SCALING_GOVERNOR_ON_BAT=powersave\nCPU_BOOST_ON_AC=1\nCPU_BOOST_ON_BAT=0\nWIFI_PWR_ON_AC=off\nWIFI_PWR_ON_BAT=on\nSOUND_POWER_SAVE_ON_AC=0\nSOUND_POWER_SAVE_ON_BAT=1\n' > /etc/tlp.d/01-macbook.conf

# Create ruv user
RUN useradd -m -s /bin/bash -G sudo,audio,video,plugdev,bluetooth ruv && \
    echo "ruv:ruv" | chpasswd && \
    echo "ruv ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ruv && \
    chmod 440 /etc/sudoers.d/ruv

# Copy user config files
COPY config/includes.chroot/etc/skel/.bashrc /home/ruv/.bashrc
COPY config/includes.chroot/etc/skel/.ruos-first-login.sh /home/ruv/.ruos-first-login.sh
COPY config/includes.chroot/etc/skel/brain-data/ /home/ruv/brain-data/

# Desktop shortcuts
RUN mkdir -p /home/ruv/Desktop && \
    cp /usr/share/applications/firefox.desktop /home/ruv/Desktop/ && \
    cp /usr/share/applications/org.mixxx.Mixxx.desktop /home/ruv/Desktop/ && \
    cp /usr/share/applications/spotify.desktop /home/ruv/Desktop/ && \
    cp /usr/share/applications/xfce4-terminal.desktop /home/ruv/Desktop/ && \
    cp /usr/share/applications/thunar.desktop /home/ruv/Desktop/ && \
    printf '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Install ruOS to Disk\nComment=Install ruOS to the internal SSD\nExec=xfce4-terminal -e "sudo ruos-install-to-disk"\nIcon=system-software-install\nTerminal=false\nCategories=System;\n' > /home/ruv/Desktop/ruos-install.desktop && \
    chmod +x /home/ruv/Desktop/*.desktop && \
    chown -R ruv:ruv /home/ruv

# Pre-configure Mixxx for DDJ-200
RUN mkdir -p /home/ruv/.mixxx && \
    printf '[Controls]\nAutoDjTransition=4\nRateDir=1\n\n[Library]\nRescanOnStartup=0\n\n[Soundcard]\nLatency=5\nSampleRate=44100\n\n[Controller1]\nEnabled=true\nScript=Pioneer-DDJ-200-scripts.js\nMapping=Pioneer DDJ-200.midi.xml\n' > /home/ruv/.mixxx/mixxx.cfg && \
    chown -R ruv:ruv /home/ruv/.mixxx

# Verify key components
RUN echo "=== ruOS MacAir v0.2.0 Build Verification ===" && \
    echo "Firefox: $(firefox --version 2>/dev/null)" && \
    echo "Node: $(node --version)" && \
    echo "Spotify: $(dpkg -s spotify-client 2>/dev/null | grep Version)" && \
    echo "Mixxx: $(dpkg -s mixxx 2>/dev/null | grep Version)" && \
    echo "Tailscale: $(tailscale version 2>/dev/null | head -1)" && \
    echo "GPU: $(dpkg -s xserver-xorg-video-intel 2>/dev/null | grep Version)" && \
    echo "ruOS bins:" && ls -1 /usr/local/bin/ruvultra-* /usr/local/bin/mcp-brain* 2>/dev/null && \
    echo "Desktop:" && ls -1 /home/ruv/Desktop/ && \
    echo "=== Verification complete ==="

USER ruv
WORKDIR /home/ruv

CMD ["/bin/bash"]
