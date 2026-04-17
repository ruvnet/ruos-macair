# ADR-001: ruOS for MacBook Air 2012

**Status:** Accepted
**Date:** 2026-04-17
**Author:** ruv

## Context

A 2012 MacBook Air (Ivy Bridge i5/i7, 4-8GB RAM, Intel HD 4000, Broadcom BCM4360 WiFi) needs a dedicated ruOS installation optimized for its hardware constraints. The machine will serve as a portable ruOS workstation with DJ capabilities (Pioneer DDJ-200) and music streaming (Spotify).

## Decision

Build a bootable USB-based ruOS installation using Docker-validated rootfs extraction rather than live-build, targeting the specific hardware profile of the 2012 MacBook Air.

### Architecture

```
USB Drive (14.3GB Cruzer Spark, GPT)
├── sda1: EFI System Partition (512MB, FAT32)
│   └── EFI/BOOT/BOOTX64.EFI (GRUB)
└── sda2: Root Filesystem (13.8GB, ext4)
    └── Ubuntu 24.04 Noble + ruOS overlay
```

### Build Pipeline

1. **Docker validation** — Full image built and verified in container before touching hardware
2. **Rootfs export** — `docker export` produces a clean tarball (2.7GB)
3. **USB partitioning** — GPT with EFI SP + ext4 root (MacBook Air 2012 requires EFI boot)
4. **Chroot kernel install** — linux-image-generic 6.8.0 + GRUB EFI installed inside rootfs
5. **Hardware config overlay** — GPU, trackpad, keyboard, WiFi, power, audio configs baked in

### Hardware Optimization

| Component | Driver/Config | Notes |
|-----------|--------------|-------|
| GPU | `xserver-xorg-video-intel`, SNA accel, DRI3, TearFree | Intel HD 4000 (Ivy Bridge) |
| Video decode | `intel-media-va-driver` (VA-API) | Hardware H.264/VP8 decode |
| WiFi | `bcmwl-kernel-source` (broadcom-sta) | BCM4360, pre-configured with ruv.net credentials |
| Keyboard | `hid_apple fnmode=2, swap_opt_cmd=1` | Fn keys as F-keys, Cmd↔Option swap |
| Trackpad | `libinput` with tapping, natural scroll, clickfinger | MacBook multitouch |
| Power | TLP with MacBook-specific governor and WiFi power profiles | Battery optimization |
| Thermal | `thermald` | Ivy Bridge thermal management |

### Software Stack

| Layer | Components |
|-------|-----------|
| Desktop | XFCE 4.18 (light, 4-8GB RAM friendly) |
| Network | NetworkManager, Tailscale (mesh VPN) |
| Audio | PipeWire + ALSA, low-latency DJ config (`rtprio 99`, `memlock unlimited`) |
| DJ | Mixxx 2.4 + DDJ-200 USB MIDI udev rules |
| Music | Spotify (native .deb) |
| ruOS Core | ruvultra-mcp, ruvultra-profile, ruvultra-embedder, ruvultra-init, mcp-brain, mcp-brain-server-local |
| Dev Tools | Node.js 22, build-essential, git, Rust (first-login install) |
| Brain | brain.rvf (2.2MB, pre-loaded in ~/brain-data/) |

### User Configuration

- **User:** `ruv` (passwordless sudo, auto-login via LightDM)
- **WiFi:** ruv.net pre-configured with WPA-PSK
- **First login:** Automated Rust + Claude Code + claude-flow installation via `~/.ruos-first-login.sh`

## Alternatives Considered

### 1. live-build ISO
**Rejected.** Ubuntu's `live-build` inherits Debian-mode defaults (security.debian.org, debian-archive-keyring) that conflict with Ubuntu Noble repos. Requires extensive mirror patching and produces a live ISO rather than an installable system.

### 2. Minimal Ubuntu Server + manual package install
**Rejected.** Requires network on first boot and manual desktop setup. USB with baked-in rootfs is faster and works offline.

### 3. Pre-built Ubuntu Desktop ISO + post-install script
**Rejected.** 4.5GB base ISO fills most of the 14.3GB USB. No room for customization or persistence. Doesn't include MacBook-specific drivers out of the box.

## Consequences

- **Positive:** Reproducible build via Docker → USB pipeline. All hardware drivers baked in. Works offline. First boot connects to WiFi automatically.
- **Positive:** Docker image (`ruos-macair:0.1`) serves as both validation environment and build artifact.
- **Negative:** USB ext4 root is slower than NVMe — acceptable for a 2012 MacBook Air's SATA SSD speeds.
- **Negative:** Kernel updates require rebuilding the USB or running `apt upgrade` on the live system.
- **Risk:** Broadcom WiFi driver (`bcmwl-kernel-source`) may need rebuild on kernel updates. Mitigated by DKMS.

## Boot Instructions

1. Insert USB into MacBook Air
2. Power on, hold **Option (⌥)** key
3. Select **EFI Boot** from boot menu
4. GRUB shows "ruOS" — boots in ~30 seconds
5. Auto-login as `ruv`, WiFi connects to ruv.net automatically
6. First login runs Rust + Claude Code setup (~5 min with WiFi)
