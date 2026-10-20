# Storage, Media, and Backup Architecture

**Document Version**: 1.1.0  
**Last Updated**: 2026-10-20  
**Status**: 📋 Active Architectural Blueprint  

---

## 1. Executive Summary & Philosophy

This document outlines the personal data sovereignty and media architecture for `sam-desktop` and associated household devices. The goal is to systematically transition away from proprietary commercial cloud ecosystems (Google One, Netflix, Prime, Disney+) in favour of a self-hosted, privacy-first, and highly resilient infrastructure.

The desktop is the **working and ripping machine**; always-on household services (Jellyfin, Immich) run on a **separate off-site Linux server** (see Section 5), because the desktop dual-boots and its data drive is NTFS.

### Core Principles
1. **Data Sovereignty**: Complete ownership of personal documents, family memories, business files, and media.
2. **3-2-1 Backup Rule**: 3 copies of data, 2 distinct media formats (internal NVMe/SSD + external USB), 1 offsite encrypted copy.
3. **Selective Encryption**: 
   - **Readable where practical** (local USB drives and kDrive for emergency plug-and-read access).
   - **Encrypted where necessary** (offsite cold storage using zero-knowledge client-side encryption).
4. **Subscription Elimination**: Replacing monthly cloud storage and streaming fees (£30–£50/month) with low-cost physical media, self-hosted Jellyfin, and dedicated offsite backup nodes.

---

## 2. Filesystem Taxonomy (`~/Data/`)

The primary data drive is a 3.7 TB usable encrypted partition (`/dev/mapper/cryptdata`), shared with Windows and therefore formatted as NTFS.

| OS | Path | Notes |
| :--- | :--- | :--- |
| NixOS | `/mnt/data` | Real mount (`ntfs-3g`, shows as `fuseblk`); defined in `hosts/devtower-intel/data-pair.nix` |
| NixOS | `~/Data` | Bind mount of `/mnt/data` inside the home directory (home is `0700`, so system services cannot reach it here) |
| Windows | `F:\` | Same files |

Mount options: `uid=1000,gid=100,fmask=0133,dmask=0022,windows_names,nofail,noatime`. Files appear as `0644` and folders as `0755`, owned by `sam-desktop`; `windows_names` stops Linux creating names Windows cannot open. Because of `nofail`, the drive may be absent until unlocked: anything that depends on it must use `RequiresMountsFor=/mnt/data`.

```
~/Data/
├── personal/            # Curated personal archive & active personal files
│   ├── docs/            # PDFs, contracts, notes, certificates, projects
│   ├── photos/          # Curated photo library & historical archives
│   ├── videos/          # Family videos, clips, steelseries-moments
│   ├── audio/           # Sound clips, music, voice recordings
│   ├── design/          # PSD, AI, Sketch, Figma files
│   └── assets/          # 3D models, fonts, archive packs
├── business/            # Syntek & company records, client work, accounts
│   ├── film/            # DaVinci Resolve projects, media, renders
│   └── docs/            # Client documentation, legal, invoicing
├── immich/              # Local copy of Immich uploads pulled from the server (planned)
│   ├── sam/             # Sam's mobile camera roll backups
│   └── heather/         # Heather's mobile camera roll backups
├── jellyfin/            # Master copy of the media library (rip output, F:\jellyfin\ on Windows)
│   ├── movies/          # Film library (Title (Year)/Title (Year).mkv)
│   └── shows/           # Series library (Show/Season XX/SXXEXX.mkv)
├── archive/             # Static cold snapshots & historical backups
└── CacheClip/           # DaVinci Resolve temporary render cache
```

`jellyfin/` and `immich/` do not exist yet; create them when ripping starts.

### Naming Conventions
* **Directories / Folders**: Strict `kebab-case` (`camera-uploads/`, `steelseries-moments/`, `code-institute/`, `house-maintenance/`).
* **Files**: Strict `snake_case` (`birth_certificate.pdf`, `wedding_service_booklet.pdf`, `film_notices_2.docx`).
* **Media Tagging**: Dates formatted as `YYYY-MM-DD` or `YYYY_MM_DD` preceding the title.

### Dual-Boot Operation (NixOS & Windows)
* **NTFS Character Encoding**: NTFS forbids `:`, `*`, `?`, `"`, `<`, `>`, `|`. On Linux, Rclone commands targeting this drive must enforce:
  `--local-encoding "Slash,LtGt,DoubleQuote,Colon,Question,Asterisk,Pipe,BackSlash,Ctl,RightSpace,RightPeriod,InvalidUtf8,Dot"`
* **Windows Fast Startup & Hibernation**: Must be turned **OFF** to avoid leaving the NTFS filesystem in a hibernated/dirty state when rebooting into NixOS.
* **macOS-made archives**: Zips from a Mac include `.DS_Store` (and sometimes `__MACOSX/`) Finder metadata. Harmless; delete with `find <dir> -name .DS_Store -delete`.

### What NTFS Cannot Host
* **Databases (Postgres)**: Immich's Postgres data directory must be on a filesystem with Unix ownership and permissions (ext4, XFS, Btrfs, ZFS…). Immich documents that it does not work on NTFS, including from WSL. An ext4 virtual disk file on NTFS shared between both OSes was considered and rejected as too fragile; the database lives on the off-site server instead.
* **Shared application state**: A Jellyfin install on each OS would keep separate libraries, users and watch history (no built-in sync). The media files themselves are shared fine.

---

## 3. Tiered Backup Strategy

Different data types require different backup frequencies, formats, and encryption targets.

```
                                  ┌─────────────────────────────┐
                                  │ Primary Storage: ~/Data/    │
                                  └──────────────┬──────────────┘
                                                 │
          ┌──────────────────────────────────────┼──────────────────────────────────────┐
          ▼                                      ▼                                      ▼
┌───────────────────────────────┐ ┌───────────────────────────────┐ ┌───────────────────────────────┐
│     Tier 1: Readable Cloud    │ │     Tier 2: Readable USB      │ │    Tier 3: Encrypted Cloud    │
│      (Infomaniak kDrive)      │ │     (External Hard Drive)     │ │   (Hetzner / Swiss Backup)    │
├───────────────────────────────┤ ├───────────────────────────────┤ ├───────────────────────────────┤
│ • Tool: Rclone Sync           │ │ • Tool: Rsync / Rclone        │ │ • Tool: Restic                │
│ • Unencrypted / Plaintext     │ │ • Tool: Plug-and-read mirror  │ │ • Client-side AES-256-GCM     │
│ • Docs only (< 20 GB)         │ │ • Full ~/Data/ mirror         │ │ • Deduplicated snapshots      │
│ • Read-only access from phone │ │ • Offline physical safety     │ │ • Point-in-time prune history │
└───────────────────────────────┘ └───────────────────────────────┘ └───────────────────────────────┘
```

### Backup Matrix

| Target Destination | Purpose | Tools Used | Included Paths | Excluded Paths |
| :--- | :--- | :--- | :--- | :--- |
| **Infomaniak kDrive** | Rapid document lookup on phone/laptop anywhere | `rclone sync` | • `personal/docs/`<br>• `business/docs/` | ❌ `jellyfin/`<br>❌ `immich/`<br>❌ Video libraries |
| **External USB Disk** | Emergency plug-and-read hardware copy | `rsync -av --delete` | • `personal/`<br>• `business/`<br>• `immich/`<br>• `jellyfin/` | Temporary caches |
| **Hetzner Storage Box / Swiss Backup** | Zero-knowledge cold disaster recovery | `restic` | • `personal/`<br>• `business/`<br>• `immich/upload/`<br>• Jellyfin metadata | `thumbs/`, `encoded-video/`, `CacheClip/` |
| **Off-site server → backup target** | Recovery of server state | `restic` (from the server) | • Immich Postgres dumps<br>• Immich `upload/`<br>• Jellyfin config/metadata | Transcode & thumbnail caches |

The off-site server is not a backup: its disks hold the live copy. The desktop's `~/Data/jellyfin/` remains the master copy of the media library, and Immich uploads should be pulled back to `~/Data/immich/` so the 3-2-1 rule still holds.

### Key Tool Commands

#### 1. Rclone to kDrive (Lightweight Document Sync)
```bash
rclone sync ~/Data/personal/docs/ kdrive:personal-docs/ \
    --local-encoding "Slash,LtGt,DoubleQuote,Colon,Question,Asterisk,Pipe,BackSlash,Ctl,RightSpace,RightPeriod,InvalidUtf8,Dot" \
    --transfers 4 -P
```

#### 2. Restic to Hetzner Storage Box (Encrypted Snapshot)
```bash
# Repository initialized over SFTP: sftp:uXXXXXX@uXXXXXX.your-storagebox.de:backup-restic
restic -r sftp:uXXXXXX@uXXXXXX.your-storagebox.de:backup-restic backup \
    ~/Data/personal/ \
    ~/Data/business/ \
    ~/Data/immich/upload/ \
    --exclude "~/Data/CacheClip" \
    --exclude "**/.cache"
```

#### 3. USB Physical Mirror
```bash
rsync -avh --delete --modify-window=1 \
    /home/sam-desktop/Data/ \
    /run/media/sam-desktop/BACKUP_USB/Data/
```

---

## 4. Self-Hosted Household Services

Both services run on the off-site server (Section 5). Nothing below runs on the desktop.

### A. Immich Photo Management
* **Multi-User Topology**:
  * `sam`: Dedicated user account & mobile sync endpoint.
  * `heather`: Dedicated user account & mobile sync endpoint.
* **Partner Sharing**: Configured in Immich to allow shared timeline and album visibility while keeping private uploads discrete.
* **Storage layout on the server**: Postgres, Valkey/Redis and thumbnails on SSD/NVMe (never object storage or a network share); originals on bulk storage.
* **External Library**: A read-only copy of `~/Data/personal/photos/` synced to the server, indexing 25,000+ historical archive photos with facial recognition, search, and world-map geotagging.
* **Redis/Valkey**: Only a job queue; needs no persistence or backup.

### B. Jellyfin Media Streaming
* **Purpose**: Completely replace subscription streaming platforms (Netflix, Disney+, Prime).
* **One instance only**: Running on the server gives one library and watch history whichever OS the desktop is booted into. On the desktop, files can still be played locally from `~/Data/jellyfin/` (`F:\jellyfin\`) with VLC/mpv.
* **Library sync**: `rsync` (or `rclone` for object storage) from `~/Data/jellyfin/` to the server after each rip.
* **Multi-Disc Extended Cuts** (e.g. *Lord of the Rings*):
  * Handled via naming pattern: `Film (Year) - part1.mkv` and `Film (Year) - part2.mkv`.
  * Or merged losslessly via `mkvmerge -o "Film (Year).mkv" "part1.mkv" + "part2.mkv"`.
* **Direct play first**: Server-side transcoding is either CPU-only or an Intel iGPU (provider-dependent), so encode for direct play rather than relying on transcoding.

### C. Ripping & Encoding (Desktop) ✅ Installed
* **Tools**: `makemkv` and `handbrake` (`modules/software/media.nix`), plus the `sg` kernel module MakeMKV needs to see optical drives and the `cdrom` group for `sam-desktop` (`modules/users/devtower.nix`). Log out and back in after the first rebuild for the group to apply.
* **Workflow**:
  1. **MakeMKV**: Lossless bit-for-bit rip directly from optical disc (8–12 minutes).
  2. **HandBrake**: Compressed with H.264/H.265 (HEVC), AAC/AC3 audio, and SRT text subtitles.
  3. **Output**: `/mnt/data/jellyfin/movies/` or `shows/` (`F:\jellyfin\` on Windows).
  4. **Direct Play Target**: 100% direct-play compatibility on Samsung Smart TV, Fire TV Stick 4K, Apple TV, iOS, and Android.
* **GPU Hardware Independence**:
  * Resulting `.mkv` files are universal standards.
  * Encoding on AMD (via Linux `VA-API`) or NVIDIA (via `NVENC`) has zero impact on client playback compatibility.

---

## 5. Off-Site Server (Jellyfin + Immich)

**Status**: 🔲 Provider not yet chosen. Target OS: NixOS, managed as a host in this repository.

### Requirements
* Always on, independent of the desktop's dual boot.
* Linux filesystem on SSD/NVMe for Postgres; bulk storage for 1–4 TB of media now, growing.
* NixOS installable (custom image, IPMI ISO, or `nixos-anywhere` from a Debian install).
* Traffic sufficient for household streaming (well under 10 TB/month).

### Provider Comparison (researched 2026-10-20, prices ex VAT, per month)

A plain VPS does **not** fit at either provider: disks are too small (Clouvider max 350 GB; Infomaniak VPS Lite max 320 GB, VPS Cloud ~€0.10/GB capped at 3 TB) and there is no GPU.

| | Clouvider: E-2276G dedicated (London) | Infomaniak: Public Cloud + Swift (Switzerland) |
| :--- | :--- | :--- |
| Configuration | 6C/12T, Intel UHD 630 iGPU, 480 GB NVMe, 2× HDD mirrored | 4 vCPU / 16 GB instance, 512 GiB perf1 block volume, media in Swift object storage |
| ~2 TB media | £109 (2× 4 TB, 4 TB usable) | €80 |
| ~4 TB media | £109 (tight) / £131 (2× 8 TB + 32 GB RAM) | €99 |
| ~8 TB media | £131 | ~€140, rising ~€9.70/TiB |
| Media storage | Local mirrored HDDs | Object storage via `rclone` mount (slower scans/seeking) |
| Transcoding | iGPU Quick Sync (unconfirmed, see below) | CPU only (GPU instances from ~€107/month) |
| NixOS | "None" + ISO over IPMI, or Debian 13 + `nixos-anywhere` | Upload custom image, or `nixos-anywhere` |
| Traffic | 50 TB included | Free (object storage egress above 10 TB charged) |
| Latency / jurisdiction | Low from UK / UK | Higher / Switzerland (stronger privacy) |
| Billing | Fixed monthly | Hourly; €300 starter credit (3 months) |

**Budget alternatives**:
* Clouvider E3-1270 v6, HDD only, no iGPU: £82 with 2× 4 TB mirrored (Postgres on spinning disk; direct play only).
* Infomaniak VPS Lite 4 vCPU / 8 GB (annual) + Swift: ~€37 (2 TB) / ~€57 (4 TB); official images only, NixOS unsupported.

**Leaning**: Clouvider E-2276G for a growing disc library (local disks, iGPU, UK latency, cheaper beyond ~6–8 TB); Infomaniak Public Cloud if Swiss jurisdiction matters most or the library stays under ~4 TB. Either way, off-site backup goes to a different provider (e.g. Infomaniak Swiss Backup, ~€4/TB, if the server is at Clouvider).

**To confirm before ordering**:
* Clouvider: `/dev/dri` (iGPU) usable on the E-2276G boards; acceptable-use policy permits media streaming; 12 TB+ HDD prices (£260–390 listed, likely errors); VPS ISO/OS options.
* Infomaniak: custom image upload limit (docs say 100 GB, error table says 2 GiB); UK VAT treatment.

Sources: `clouvider.com/dedicated-servers/`, `console.clouvider.co.uk/cart/…`, `infomaniak.com/en/hosting/public-cloud/prices`, `docs.infomaniak.cloud/compute/images/custom_images/`, `infomaniak.com/en/hosting/vps-lite`.

---

## 6. Network Access & Remote Connectivity

```
[Mobile / Laptop / TV]
        │ (WireGuard tunnel)
        ▼
[Off-site server (NixOS)]
        ├── Jellyfin  ──► Streaming Media (port 8096, WireGuard/allow-listed only)
        └── Immich    ──► Mobile Camera Roll Sync (port 2283, WireGuard/allow-listed only)
        ▲
        │ rsync / restic over WireGuard or SSH
[sam-desktop (NixOS)] ── Samba (SMB) ──► LAN shares for laptops (ports 139, 445)
```

1. **Plain WireGuard (No Third-Party Brokers)**:
   * Kernel-level WireGuard on the server, which has a static public IP: no router port-forward or Dynamic DNS needed for the services.
   * Remote mobile devices connect using the official WireGuard app via QR code (`qrencode`).
   * Jellyfin and Immich ports are not opened publicly (`openFirewall = false`); allow them on the WireGuard interface only.
   * TVs that cannot run WireGuard need either a home-side WireGuard gateway or a reverse proxy with TLS and authentication; decide when the server is provisioned.
2. **Samba (LAN File Sharing)**:
   * Shares `personal`, `business`, and `jellyfin` from the desktop across the local network.
   * Compatible with Windows Explorer, macOS Finder, Linux, and iOS/Android Files apps.

---

## 7. NixOS Declarative Configuration Reference

### A. Desktop Packages ✅ Implemented
| Package | Location |
| :--- | :--- |
| `file` | `modules/core/common.nix` (all hosts) |
| `makemkv`, `handbrake` + `boot.kernelModules = [ "sg" ]` | `modules/software/media.nix` |
| `cdrom` group | `modules/users/devtower.nix` |
| `rclone`, `wireguard-tools`, `unzip`/`zip`/`p7zip` | `modules/core/common.nix` (already present) |
| `mkvtoolnix`, `restic`, `rsync`, `qrencode` | 🔲 Not yet added |

`nixpkgs.config.allowUnfree = true` (needed for MakeMKV) is already set in `modules/core/common.nix`.

### B. Jellyfin (Server Host)
```nix
services.jellyfin = {
  enable = true;
  openFirewall = false; # reach it over WireGuard only
};

# Do not start (and scan an empty library) before the media storage is mounted
systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/srv/media" ];

networking.firewall.interfaces.wg0.allowedTCPPorts = [ 8096 ];

# Intel iGPU (e.g. UHD 630) hardware transcoding via VA-API / Quick Sync
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [ intel-media-driver ];
};
users.users.jellyfin.extraGroups = [ "render" "video" ];
```

### C. Immich (Server Host)
Use the NixOS `services.immich` module on the server: it manages Postgres (with the required vector extension) and Redis/Valkey on the server's own Linux filesystem. Keep `services.immich.mediaLocation` on bulk storage and the database on SSD/NVMe. Configure exact options from the current NixOS module documentation when the host is created.

### D. Samba Sharing Configuration (Desktop)
```nix
services.samba = {
  enable = true;
  openFirewall = true;
  settings = {
    global = {
      "workgroup" = "WORKGROUP";
      "server string" = "sam-desktop";
      "security" = "user";
      "hosts allow" = "192.168.1. 10.100.0. 127.0.0.1";
      "hosts deny" = "0.0.0.0/0";
    };
    personal = {
      path = "/home/sam-desktop/Data/personal";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "sam-desktop";
    };
    jellyfin = {
      path = "/home/sam-desktop/Data/jellyfin";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "sam-desktop";
    };
  };
};
```

### E. WireGuard Server Configuration (Server Host)
```nix
networking.wireguard.interfaces.wg0 = {
  ips = [ "10.100.0.1/24" ];
  listenPort = 51820;
  privateKeyFile = "/etc/wireguard/private.key"; # move to agenix secret
  
  peers = [
    # Sam Mobile
    {
      publicKey = "<SAM_MOBILE_PUBLIC_KEY>";
      allowedIPs = [ "10.100.0.2/32" ];
    }
    # Heather Mobile
    {
      publicKey = "<HEATHER_MOBILE_PUBLIC_KEY>";
      allowedIPs = [ "10.100.0.3/32" ];
    }
    # sam-desktop (library sync and backups)
    {
      publicKey = "<SAM_DESKTOP_PUBLIC_KEY>";
      allowedIPs = [ "10.100.0.4/32" ];
    }
  ];
};

networking.firewall.allowedUDPPorts = [ 51820 ];
```

---

## 8. Migration Timeline & Checklist

- [x] **Bulk Google Drive Download**: 551 GB (34,072 files) downloaded via Rclone.
- [x] **File Sorting & Formatting**: Renamed to kebab-case folders / snake_case files and moved into `~/Data/personal/`.
- [x] **Business Drive Download**: Business My Drive and Shared Drive synced to `~/Data/business/`.
- [x] **Ripping Tools**: MakeMKV, HandBrake, `sg` module and `cdrom` group added to the desktop config (rebuild pending).
- [ ] **1-Week Observation Window**: Ensure all files are intact locally.
- [ ] **Google Drive Purge**: Delete files from Drive, empty trash bin, confirm total usage under 15 GB, and cancel Google One.
- [ ] **Custom Domain & Email**: Acquire domain, configure Infomaniak mail, run IMAP import from `samabailey6194@gmail.com`.
- [ ] **Local USB Mirror**: Set up rsync job to external drive.
- [ ] **Start Ripping**: Create `~/Data/jellyfin/{movies,shows}/` and rip discs locally.
- [ ] **Choose Server Provider**: Confirm open questions in Section 5 with Clouvider / Infomaniak, then order.
- [ ] **Provision Server**: Install NixOS (`nixos-anywhere`), add as a host in this repository with WireGuard and agenix secrets.
- [ ] **Jellyfin Deployment**: Enable Jellyfin on the server; sync `~/Data/jellyfin/` to it.
- [ ] **Immich Deployment**: Configure Immich for Sam & Heather on the server; sync `~/Data/personal/photos/` as an external library.
- [ ] **Encrypted Offsite Backup**: Initialise Restic repos for the desktop and the server on a separate provider (Hetzner Storage Box / Swiss Backup).
