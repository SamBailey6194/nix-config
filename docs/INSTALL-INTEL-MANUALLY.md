# Manual Intel desktop installation

This is the **replace-Ubuntu-on-Intel** procedure. You have asked to perform
the installation manually; nothing here has been run against your disks.
Use this procedure only if you choose to erase the Intel 256GB OS disk.
If you choose dual boot instead, stop before partitioning and plan a different
target. Read [the inventory and preservation plan](UBUNTU-TO-NIXOS.md) first.

Commands below run in a root Bash shell in a NixOS UEFI live installer unless
stated otherwise. Execute one block at a time and inspect its results.
Keep the backup password and LUKS passphrase independently of this PC.

## 1. Prepare on Ubuntu

Record the current configuration and disk inventory somewhere outside Intel.
The repository, including these uncommitted files, lives in your retained
Samsung home; include the whole directory in the backup. Do not rely on a fresh
Git clone to contain the new untracked files.

```sh
cd /home/sam-dev/Repos/personal/nix-config
git status --short
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,UUID,MOUNTPOINTS
for path in / /home /nix /var/lib/docker; do findmnt -T "$path"; done
sudo blkid
```

Before shutting down, preserve the active VPN and accountability credentials:

```sh
sudo python3 scripts/export-ubuntu-migration-secrets.py
```

This creates three root-only files under `/etc/nixos-migration`, validates the
existing desktop VPN identity, and sends no messages. Include them in the root
backup below. If it fails, resolve that before losing Ubuntu's current access.
See [desktop connectivity and accountability](DESKTOP-CONNECTIVITY.md).

Export application databases using their normal dump tools. Stop containers
cleanly, record what was running, and fully shut down Ubuntu. Do not hibernate.
Create a NixOS installer USB using another computer or a carefully verified USB
target. Boot it in **UEFI** mode. Use wired networking if possible. The current
configuration uses systemd-boot, so arrange firmware settings that allow it to
boot; Secure Boot signing/enrolment is a separate setup task.

If using your already prepared `backup-before-nixos.sh` copy, read
[the live-backup review and installer adaptation](LIVE-BACKUP-SCRIPT.md) first.
That copy is unencrypted and requires offline verification; section 2 below
uses an encrypted Restic repository instead.

## 2. Mount source data and make an encrypted offline backup

In the live environment:

```sh
sudo -i
bash
test -d /sys/firmware/efi && echo 'UEFI boot confirmed'
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,UUID,MOUNTPOINTS
nix-shell -p restic cryptsetup parted btrfs-progs git rsync python3 ripgrep nano
mkdir -p /media/ubuntu-root /media/ubuntu-home /media/ubuntu-nix /media/ubuntu-docker /media/archive /media/backup /media/ubuntu-efi /media/home-efi /media/archive-efi
mount -o ro,noload /dev/disk/by-uuid/e9605dca-3609-4cd7-be0b-cfac0661111e /media/ubuntu-root
mount -o ro,noload /dev/disk/by-uuid/8eaacce9-a3bd-4e95-924c-feb9e2d050b4 /media/ubuntu-home
mount -o ro,noload /dev/disk/by-uuid/af95812e-4174-4c02-94fd-a142a7981165 /media/ubuntu-nix
mount -o ro,noload /dev/disk/by-uuid/0bb16801-79b4-435d-b8f6-646e3e12b38c /media/ubuntu-docker
mount -o ro,noload /dev/disk/by-uuid/9f544f15-8e9a-45de-9951-d84f51b62e57 /media/archive
mount -o ro /dev/disk/by-uuid/27BE-92E7 /media/ubuntu-efi
mount -o ro /dev/disk/by-uuid/244E-5B6F /media/home-efi
mount -o ro /dev/disk/by-uuid/2537-6BE7 /media/archive-efi
mount /dev/disk/by-uuid/883736aa-556a-4e5e-b42f-e58bd40f5668 /media/backup
findmnt /media/backup
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,UUID,MOUNTPOINTS
df -h /media/backup
```

If a mount fails, stop and resolve it; do not substitute a random device.
Read-only/no-journal-replay mounts assume a cleanly shut down source.
The destination must be Backup+ Hub BK, serial `NA9R0S9H`, label
`BackupDrive`, ext4 UUID `883736aa-556a-4e5e-b42f-e58bd40f5668`.
Its main filesystem is currently `sdf2`; the 128MiB `sdf1` partition is not the
backup filesystem. Do not format either partition. Device letters can change.
The observed 8.6TiB free exceeds the roughly 1.55TiB used by these Ubuntu data
filesystems; verify free space again in the installer. The archive is now a
backup **source**, so its contents are protected independently as well.

```sh
export RESTIC_REPOSITORY=/media/backup/ubuntu-before-nixos-restic
restic init
restic backup --one-file-system --tag before-nixos /media/ubuntu-root /media/ubuntu-home /media/ubuntu-nix /media/ubuntu-docker /media/archive /media/ubuntu-efi /media/home-efi /media/archive-efi
restic snapshots
restic check --read-data
restic ls latest /media/ubuntu-home/sam-dev/Repos/personal/nix-config
mkdir -p /tmp/restore-check
restic restore latest --target /tmp/restore-check --include /media/ubuntu-home/sam-dev/.claude.json --include /media/ubuntu-root/etc/fstab --include /media/ubuntu-root/etc/nixos-migration --include /media/ubuntu-home/sam-dev/.config/wireguard/sam-desktop
cmp /media/ubuntu-home/sam-dev/.claude.json /tmp/restore-check/media/ubuntu-home/sam-dev/.claude.json
cmp /media/ubuntu-root/etc/fstab /tmp/restore-check/media/ubuntu-root/etc/fstab
for file in arwyn-private.key arwyn-psk.key squid-digest.env; do
  cmp "/media/ubuntu-root/etc/nixos-migration/$file" "/tmp/restore-check/media/ubuntu-root/etc/nixos-migration/$file" || exit 1
done
```

Restic prompts for an encryption password. If that repository already exists,
use its known password and skip `init`. The backup and full data check can take
hours. Confirm all commands succeed, that the repository snapshot includes the
new config files, and that representative personal files/database dumps restore.
Do not print restored credential files. If a check fails, do not proceed.
This is a filesystem backup, not a bootable disk image: record disk layouts and
UUIDs as well. Follow [backup verification and staged data-drive encryption](BACKUP-AND-DATA-ENCRYPTION.md)
before encrypting any additional drive. Keep BackupDrive physically disconnected
during formatting to protect the only independent copy.
Restic has no automatic database-consistency guarantee; the prior clean stop
and database exports matter.

## 3. Identify the Intel target again

Unmount the old Intel root after backup. Do not unmount the retained home you
will copy the configuration from.

```sh
umount /media/ubuntu-root
ls -l /dev/disk/by-id/nvme-INTEL*
```

Set `INSTALL_DISK` to the **whole-disk by-id symlink** shown for serial
`PHHH93710CN8256B`, not a `-partN` symlink. Type the observed path yourself:

```sh
read -r -p 'Whole Intel disk by-id path: ' INSTALL_DISK
readlink -f "$INSTALL_DISK"
lsblk -d -o NAME,SIZE,MODEL,SERIAL "$INSTALL_DISK"
lsblk -o NAME,SIZE,FSTYPE,UUID,MOUNTPOINTS "$INSTALL_DISK"
```

It must be the Intel 256GB drive, with the Ubuntu root/EFI/swap inventory above.
There must be no mounted target partitions. If anything differs, stop.
The next section irreversibly destroys its current partition layout.
Do not run it until your backup and restoration checks have passed.

## 4. Erase only the confirmed Intel disk and create LUKS2

These commands are destructive. They explicitly guard the serial and require
you to type the erasure acknowledgement. They are for the chosen Intel target
only, not any Samsung, Seagate, Crucial or WD drive.

```sh
test -b "$INSTALL_DISK" || exit 1
test "$(lsblk -dn -o SERIAL "$INSTALL_DISK" | tr -d ' ')" = PHHH93710CN8256B || exit 1
read -r -p 'Type ERASE-INTEL-PHHH93710CN8256B after backup verification: ' CONFIRM_ERASE
test "$CONFIRM_ERASE" = ERASE-INTEL-PHHH93710CN8256B || exit 1
parted --script "$INSTALL_DISK" mklabel gpt
parted --script "$INSTALL_DISK" mkpart NIXOS_ESP fat32 1MiB 2049MiB
parted --script "$INSTALL_DISK" set 1 esp on
parted --script "$INSTALL_DISK" mkpart NIXOS_CRYPT 2049MiB 100%
udevadm settle
INSTALL_ESP="${INSTALL_DISK}-part1"
INSTALL_LUKS="${INSTALL_DISK}-part2"
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$INSTALL_DISK"
```

Confirm `INSTALL_ESP` and `INSTALL_LUKS` resolve to **this disk's new** 2GiB
EFI and remaining Linux partitions. Stop if they do not.

```sh
test -b "$INSTALL_ESP" && test -b "$INSTALL_LUKS" || exit 1
mkfs.fat -F 32 -n NIXOS_ESP "$INSTALL_ESP"
cryptsetup luksFormat --type luks2 "$INSTALL_LUKS"
cryptsetup open "$INSTALL_LUKS" cryptroot
mkfs.btrfs -L NIXOS_ROOT /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
for subvol in @root @nix @snapshots @log @home @docker; do btrfs subvolume create "/mnt/$subvol"; done
umount /mnt
mount -o subvol=@root,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/nix /mnt/.snapshots /mnt/var/log /mnt/home /mnt/var/lib/docker /mnt/boot
mount -o subvol=@nix,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@snapshots,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@log,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@home,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@docker,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/var/lib/docker
mount "$INSTALL_ESP" /mnt/boot
findmnt -R /mnt
cryptsetup luksHeaderBackup "$INSTALL_LUKS" --header-backup-file /tmp/intel-nixos-luks-header
restic backup --tag nixos-luks-header /tmp/intel-nixos-luks-header
```

Use a strong recoverable passphrase; do not depend on TPM auto-unlocking for
the first boot. The header backup is encrypted by Restic. Its recovery file
must be kept with its passphrase and protected like a key. Later LUKS key-slot
changes require an updated header backup.

## 5. Copy the config and enter new UUIDs

Use the new `sam-desktop` keys for `10.100.0.8`, deployed on arwyn-1. The
older `/etc/nixos-migration` WireGuard keys belong to Ubuntu at `.2` and must
not be paired with the new address. Accountability still uses that export.

```sh
install -d -m 0700 /mnt/var/lib/desktop-secrets
install -m 0400 /tmp/restore-check/media/ubuntu-home/sam-dev/.config/wireguard/sam-desktop/private.key /mnt/var/lib/desktop-secrets/arwyn-private.key
install -m 0400 /tmp/restore-check/media/ubuntu-home/sam-dev/.config/wireguard/sam-desktop/preshared.key /mnt/var/lib/desktop-secrets/arwyn-psk.key
install -m 0600 /tmp/restore-check/media/ubuntu-root/etc/nixos-migration/squid-digest.env /mnt/var/lib/desktop-secrets/squid-digest.env
install -d -m 0700 /mnt/home/sam-desktop/.ssh
install -m 0600 /media/ubuntu-home/sam-dev/.ssh/id_ed25519_admin /mnt/home/sam-desktop/.ssh/id_ed25519_admin
mkdir -p /mnt/home/sam-desktop/Repos/personal
cp -a /media/ubuntu-home/sam-dev/Repos/personal/nix-config /mnt/home/sam-desktop/Repos/personal/
cd /mnt/home/sam-desktop/Repos/personal/nix-config
git status --short
blkid -s UUID -o value "$INSTALL_ESP"
blkid -s UUID -o value "$INSTALL_LUKS"
blkid -s UUID -o value /dev/mapper/cryptroot
nano hosts/devtower-intel/disks.nix
```

Replace only `espUuid`, `luksUuid` and `btrfsUuid` with those three values, in
that order. Leave observed Ubuntu/data-drive UUIDs as inventory. Check:

```sh
rg 'REPLACE-' hosts/devtower-intel/disks.nix
```

That must return **no matches**. Do not generate a hardware configuration over
the supplied Intel module: it defines the intended subvolumes and retained mounts.

The flake has private SSH inputs using the `github-personal` alias. If fetching
them fails in the live environment, use your backed-up SSH configuration/keys
temporarily in the live system (not in the repo or Nix store), verify GitHub's
host key, and test that alias. Remove temporary copies before leaving the live
session. No SSH private key is required on an unencrypted installation USB.

## 6. Install the minimal stage first

Do not build the full CUDA desktop in the live ISO's RAM-backed store. The
minimal stage installs onto the mounted disk and establishes a bootable base:

```sh
python3 scripts/prepare-nix-source.py /tmp/nix-config-install
nix --extra-experimental-features 'nix-command flakes' eval --raw 'path:/tmp/nix-config-install#nixosConfigurations.devtower-intel-minimal.config.system.build.toplevel.drvPath'
nixos-install --no-root-passwd --flake 'path:/tmp/nix-config-install#devtower-intel-minimal'
nixos-enter --root /mnt -c 'passwd sam-desktop'
chown -R 1000:100 /mnt/home/sam-desktop
nixos-enter --root /mnt -c 'chown root:sam-desktop /var/lib/desktop-secrets /var/lib/desktop-secrets/squid-digest.env; chmod 0750 /var/lib/desktop-secrets; chmod 0640 /var/lib/desktop-secrets/squid-digest.env'
findmnt /mnt/boot
ls /mnt/boot/EFI/systemd/systemd-bootx64.efi
```

Set and remember the `sam-desktop` login/sudo password: root is locked in this
configuration. Installation must finish successfully before rebooting. The
configuration leaves firmware NVRAM entries unchanged; select this Intel ESP's
systemd-boot loader using your firmware's boot-from-file menu if necessary.
Do not change Windows or another disk's bootloader to make it work.

```sh
cd /
sync
reboot
```

## 7. First boot and staged upgrade

Unlock LUKS, log in as `sam-desktop`, verify storage and networking:

```sh
lsblk -f
for path in / /nix /home /var/lib/docker /mnt/ubuntu-home /mnt/archive; do findmnt -T "$path"; done
df -h / /boot /nix
nmcli device status
sudo cryptsetup status cryptroot
```

Keep the backup and retained files. Copy only selected files into encrypted
home; your old home is too large to copy in full. Do not copy the agent configs
or histories that hold API keys in plaintext: `~/.claude.json`,
`~/.claude/{settings.json,projects,backups,file-history}`, `~/.codex`,
`~/.gemini`, `~/.config/ai-mcp`, `~/.zsh_history`, `~/.zshenv` (exports the
Context7 key) and `~/.aws` (static IAM keys). The declarative config recreates
the configs, and the keys arrive through agenix with the full stage (section 8);
until then use `aws sso login` for AWS. Preserve SSH and age identities
before enabling any host secrets. An Ubuntu venv, system `/etc`, Nix database,
or Docker directory should not be copied wholesale onto the new active paths.
Ubuntu-owned files have UID 1000, matching the new user, but names and config
paths still need adjustment.

```sh
cd ~/Repos/personal/nix-config
nix-shell -p python3
python3 scripts/prepare-nix-source.py /tmp/nix-config-desktop
nix build --impure --no-link 'path:/tmp/nix-config-desktop#nixosConfigurations.devtower-intel-desktop.config.system.build.toplevel'
sudo nixos-rebuild switch --flake 'path:/tmp/nix-config-desktop#devtower-intel-desktop'
```

Verify Hyprland/NVIDIA/audio/media tools, then build the development stage as
your user so Nix builds run within the configured daemon budget:

```sh
python3 scripts/prepare-nix-source.py /tmp/nix-config-dev
nix build --impure --no-link --max-jobs 1 'path:/tmp/nix-config-dev#nixosConfigurations.devtower-intel-dev.config.system.build.toplevel'
sudo systemd-run --scope -p MemoryMax=16G -p MemorySwapMax=0 -- nixos-rebuild switch --flake 'path:/tmp/nix-config-dev#devtower-intel-dev' --max-jobs 1
```

The first CUDA build may take time. Do not start a model during it. After a
successful rebuild, log out/in for new groups; follow [media checks](MEDIA-WORKLOADS.md),
[model checks](LOCAL-LLM.md), [browser profile transfer](BROWSER-MIGRATION.md)
and [MCP authentication](SHARED-MCP.md).
The shared MCP activation imports keys from the retained Ubuntu Claude config
into the new encrypted home without logging them. Restore other app credentials
selectively. Add productivity/creative/full only after the dev stage works and
there is sufficient disk space. Full stage's TPM, snapshots and security settings
need their own validation; they are not prerequisites for this first install.
Enable host secrets (section 8) before switching to the full stage.

## 8. Enable host secrets, then the full stage

The full stage (`.#devtower-intel`) declares these agenix secrets in
`hosts/devtower-intel/secrets.nix`:

| Secret | Decrypted to |
|---|---|
| `github-ssh-personal`, `-syntek`, `-missionalgen` | `~/.ssh/github-devtower-intel-<account>` |
| `claude-secrets` (monitor token, Context7 + ElevenLabs keys) | `/run/agenix/claude-secrets` |
| `aws-config` | `/run/agenix/aws-config`, linked to `~/.aws/config` |
| `aws-credentials` (static IAM keys) | `/run/agenix/aws-credentials`, linked to `~/.aws/credentials` |

They are encrypted to the laptop's agenix key only, so this PC cannot decrypt
them until its own host key is a recipient. Switching to the full stage before
that only logs agenix decryption errors and leaves those files missing; finish
the steps below, then switch again.

**1. On devtower-intel, create and print the host key.** sshd is enabled only
in the full stage, so the key does not exist yet. sshd keeps an existing key,
so the one created here stays the host's identity:

```sh
sudo test -s /etc/ssh/ssh_host_ed25519_key || sudo ssh-keygen -q -t ed25519 -N '' -C root@devtower-intel -f /etc/ssh/ssh_host_ed25519_key
cat /etc/ssh/ssh_host_ed25519_key.pub
```

The `.pub` line is public; copy it to the laptop by any means.

**2. On the laptop, add it as a recipient and re-encrypt.** The laptop must
first have this repository's devtower-intel secrets work (including
`hosts/devtower-intel/secrets.nix`). If it was not pushed from Ubuntu, commit and
push it from devtower-intel using the command in step 3 with `git push`.

```sh
cd ~/Repos/personal/nix-config
git pull
$EDITOR secrets/secrets.nix
#   devtower-intel = "ssh-ed25519 AAAA... root@devtower-intel";   (uncomment, paste the line)
#   devtowerIntelKeys = [ sam-laptop devtower-intel ];
nix develop -c just rekey-secrets   # agenix -r with ~/.ssh/id_ed25519_agenix
git add secrets
git commit -m "feat(secrets): add devtower-intel host key"
git push
```

**3. On devtower-intel, pull the re-encrypted secrets.** Git rewrites this
repository's remote to the `github-personal` alias, whose key is one of the
secrets not yet decrypted. Pulls here use `--autostash` because pulls rebase
and your `disks.nix` UUID edits are uncommitted. Use the same private key from the retained Ubuntu
home for this one command (never copy it into the repository). GitHub's host
keys are pinned by `modules/core/ssh-config.nix`, so there is no prompt; a
host key warning here means something is wrong, so stop.

```sh
cd ~/Repos/personal/nix-config
GIT_SSH_COMMAND='ssh -i /mnt/ubuntu-home/sam-dev/.ssh/id_ed25519_devtower_intel_personal -o IdentitiesOnly=yes' git pull --autostash
rg 'REPLACE-' hosts/devtower-intel/disks.nix   # must return nothing
```

**4. Build and switch to the full stage, then verify.**

```sh
rm -rf /tmp/nix-config-full    # the script needs an empty destination
python3 scripts/prepare-nix-source.py /tmp/nix-config-full
nix build --impure --no-link --max-jobs 1 'path:/tmp/nix-config-full#nixosConfigurations.devtower-intel.config.system.build.toplevel'
sudo systemd-run --scope -p MemoryMax=16G -p MemorySwapMax=0 -- nixos-rebuild switch --flake 'path:/tmp/nix-config-full#devtower-intel' --max-jobs 1
sudo ls -l /run/agenix/                # aws-config, aws-credentials, claude-secrets, github-ssh-*
ls -ld ~/.ssh                          # drwx------ sam-desktop users
ls -l ~/.ssh/github-devtower-intel-* ~/.aws/config ~/.aws/credentials
ssh -T github-personal                 # Hi SamBailey6194!
ssh -T github-syntek                   # Hi Syntek-Studio!
ssh -T github-missionalgen             # Hi sam-missional-gen!
git pull --autostash                   # no GIT_SSH_COMMAND needed any more
```

`ssh -T` exits with status 1 even on success; the greeting is what matters.
From now on the shared MCP launcher reads `/run/agenix/claude-secrets` in
preference to the keys imported from the Ubuntu home.

**5. Give the fresh claude-code-monitor its token.** The monitor starts with new
server state on this PC, and creates its own API token on first start. The
hooks send `CLAUDE_MONITOR_TOKEN` from the agenix secret, so the two must match:

```sh
ccm                                    # start it once, then stop it (Ctrl+C)
jq -r .apiToken ~/Repos/claude-code-monitor/data/config.json
```

On the laptop, replace the `CLAUDE_MONITOR_TOKEN=` line with that value
(`nix develop -c just edit-secret claude-secrets-devtower-intel`), commit, push,
then here `git pull --autostash` and rerun the step 4 block (it starts from a
fresh `/tmp/nix-config-full`). Keep the other three lines.

**6. Remove the temporary plaintext copies.** Once everything above works, the
bridge copies are no longer needed:

```sh
rm -f ~/.config/ai-mcp/credentials.json ~/.zshenv.hm-backup ~/.aws/config.hm-backup ~/.aws/credentials.hm-backup
rm /mnt/ubuntu-home/sam-dev/.ssh/id_ed25519_devtower_intel_{personal,syntek,missionalgen}
```

The encrypted Restic backup still holds them. Sign in to each client's remote
MCP servers on this PC as described in [SHARED-MCP.md](SHARED-MCP.md), and run
`gh auth login` once per GitHub account (gnome-keyring keeps the tokens).

Plaintext copies of the Context7 and ElevenLabs keys, the AWS IAM access keys
and the old monitor token remain on the Ubuntu home partition, in configs,
backups and transcripts. Once this PC works, rotate those keys and update the
agenix secrets on the laptop.

## Recovery

For a failed NixOS rebuild, choose an earlier NixOS generation at boot or run
`sudo nixos-rebuild switch --rollback` from a working generation. This does not
undo disk formatting or restore Ubuntu. To recover data, boot the live USB,
mount the encrypted target with its passphrase, unlock the Restic repository and
restore selected files to a separate location first. Keep the untouched data
drives and verified backup until the new system has been used and checked.
