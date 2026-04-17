# ruOS MacBook Air 2012

Custom Linux distribution for MacBook Air Mid-2012 (A1466, Ivy Bridge) with DJ, music streaming, and ruOS agent stack.

## What's Included

| Category | Software | Notes |
|----------|----------|-------|
| Desktop | XFCE 4.18 | Lightweight, optimized for 4-8GB RAM |
| GPU | Intel HD 4000 | SNA accel, TearFree, DRI3, VA-API HW decode |
| WiFi | Broadcom BCM4360 | broadcom-sta driver, pre-configured |
| Music | Spotify | Native Linux client |
| DJ | Mixxx 2.4 | Pioneer DDJ-200 mapping pre-configured |
| VPN | Tailscale | Mesh networking |
| Dev | Node.js 22, Rust | Claude Code installed on first login |
| ruOS | mcp-brain, ruvultra-mcp, ruvultra-embedder, ruvultra-profile, ruvultra-init | Full agent stack |
| Audio | PipeWire + low-latency config | rtprio 99, memlock unlimited for DJ |
| Power | TLP | MacBook-specific battery optimization |

## Installation from Release

Download the two image parts from [Releases](https://github.com/ruvnet/ruos-macair/releases):

```bash
# Reassemble the split image
cat ruos-macair-v0.1.0.img.gz.part-aa ruos-macair-v0.1.0.img.gz.part-ab > ruos-macair-v0.1.0.img.gz

# Decompress
gunzip ruos-macair-v0.1.0.img.gz

# Write to USB (replace /dev/sdX with your USB device — use `lsblk` to find it)
sudo dd if=ruos-macair-v0.1.0.img of=/dev/sdX bs=4M status=progress
sync
```

**WARNING:** `dd` will overwrite the target device. Double-check `/dev/sdX` is your USB drive, not your system disk.

## Booting on MacBook Air

1. Insert the USB drive into the MacBook Air
2. Power on (or restart)
3. **Hold the Option (&#x2325;) key** immediately until the boot picker appears
4. Select **EFI Boot** (orange/yellow external drive icon)
5. GRUB shows "ruOS" — press Enter or wait 5 seconds
6. Auto-login as `ruv`, XFCE desktop loads
7. WiFi connects automatically

## First Login Setup

On first terminal open, the setup script runs automatically and installs:

- Rust toolchain (via rustup)
- Claude Code (via npm)
- claude-flow MCP server

This takes ~5 minutes with WiFi. A marker file (`~/.ruos-initialized`) prevents it from running again.

## Using the DJ Setup

1. Plug the **Pioneer DDJ-200** into any USB port
2. Launch Mixxx: `mixxx` or from the application menu
3. The DDJ-200 controller mapping is pre-configured — jog wheels, crossfader, EQ, and effects work out of the box
4. Audio routing: use `pavucontrol` to select output (headphones or speakers)

The system includes low-latency audio configuration for DJ use:
- Real-time priority (`rtprio 99`)
- Unlimited memory lock
- PipeWire with low-latency settings

## Tailscale VPN

```bash
sudo tailscale up
# Follow the auth URL to connect to your tailnet
tailscale status
```

## Hardware Configuration

### Keyboard
- **Fn keys** default to function keys (F1-F12), not media controls
- **Command/Option** keys are swapped for standard Linux layout
- Modify in `/etc/modprobe.d/hid-apple.conf`

### Trackpad
- Tap-to-click enabled
- Natural scrolling enabled
- Clickfinger mode (two-finger = right-click)
- Modify in `/etc/X11/xorg.conf.d/30-touchpad.conf`

### GPU
- Intel SNA acceleration with TearFree
- DRI3 enabled
- VA-API hardware video decode (H.264, VP8)
- Config: `/etc/X11/xorg.conf.d/20-intel.conf`

### Power
- TLP manages CPU governor (performance on AC, powersave on battery)
- CPU boost disabled on battery
- WiFi power saving on battery
- Config: `/etc/tlp.d/01-macbook.conf`

## Building from Source

### Docker Build (validation)

```bash
cd ruos-macair
docker build -t ruos-macair:0.1 .

# Test the image
docker run --rm -it ruos-macair:0.1
```

### Creating a Bootable USB

After validating with Docker:

```bash
# Export rootfs
docker export $(docker create ruos-macair:0.1) -o rootfs.tar

# Partition USB (GPT: 512MB EFI + rest ext4)
sudo parted /dev/sdX --script -- mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB set 1 esp on \
  mkpart root ext4 513MiB 100%
sudo mkfs.vfat -F 32 -n RUOS-EFI /dev/sdX1
sudo mkfs.ext4 -L ruOS-root /dev/sdX2

# Mount and extract
sudo mount /dev/sdX2 /mnt/ruos-root
sudo mount /dev/sdX1 /mnt/ruos-efi
sudo tar xf rootfs.tar -C /mnt/ruos-root/

# Set up chroot, install kernel + GRUB
sudo mount --bind /dev /mnt/ruos-root/dev
sudo mount --bind /dev/pts /mnt/ruos-root/dev/pts
sudo mount -t proc proc /mnt/ruos-root/proc
sudo mount -t sysfs sysfs /mnt/ruos-root/sys
sudo mkdir -p /mnt/ruos-root/boot/efi
sudo mount --bind /mnt/ruos-efi /mnt/ruos-root/boot/efi

sudo chroot /mnt/ruos-root bash -c '
  apt-get update
  apt-get install -y linux-image-generic grub-efi-amd64 efibootmgr initramfs-tools
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --no-nvram
  update-grub
'

# Write fstab with your UUIDs
ROOT_UUID=$(sudo blkid -s UUID -o value /dev/sdX2)
EFI_UUID=$(sudo blkid -s UUID -o value /dev/sdX1)
echo "UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1" | sudo tee /mnt/ruos-root/etc/fstab
echo "UUID=$EFI_UUID /boot/efi vfat umask=0077 0 1" | sudo tee -a /mnt/ruos-root/etc/fstab

# Unmount
sudo umount -R /mnt/ruos-root
sudo umount /mnt/ruos-efi
sync
```

## Default Credentials

| User | Password | Sudo |
|------|----------|------|
| `ruv` | `ruv` | Passwordless |

Change the password after first login: `passwd`

## Specs

- **Base**: Ubuntu 24.04 Noble (kernel 6.8.0-110)
- **USB layout**: GPT — 512MB EFI (FAT32) + 13.8GB root (ext4)
- **Image size**: 2.3GB compressed, 15GB uncompressed
- **Target hardware**: MacBook Air Mid-2012 (A1466, Intel Ivy Bridge)

## Architecture Decision

See [ADR-001](docs/adr/ADR-001-ruos-macbook-air-2012.md) for the full design rationale, alternatives considered, and build pipeline details.

## License

MIT
