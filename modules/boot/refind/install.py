#!@python3@/bin/python3 -B
"""Install the themed rEFInd boot menu (modules/boot/refind).

Based on nixpkgs' refind-install.py, but with one NixOS entry instead of one
per generation: the current generation boots by default, and older
generations (and specialisations) are submenu entries (F2/Insert/Tab). No
disk scanning: only NixOS, an optional Windows chainload entry and the tools
row appear.

rEFInd reads refind.conf, icons_dir, banner and font relative to its own
binary, so everything lives beside it: EFI/BOOT when installed as the
removable fallback loader, EFI/refind otherwise.
"""

import datetime
import filecmp
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from ctypes import CDLL
from typing import Any, Dict, List, Optional, Set

CONFIG = json.load(open("@configPath@"))
PROFILE = "/nix/var/nix/profiles/system"

# Every file this run installed; anything else under kernels/ and theme/ is
# from an older run and gets removed at the end.
owned: Set[str] = set()


def cfg(key: str) -> Any:
    return CONFIG[key]


def install_file(source: str, dest: str) -> None:
    """Copy source to dest (atomically, only when the content changed)."""
    owned.add(os.path.normcase(dest))
    if os.path.exists(dest) and filecmp.cmp(source, dest, shallow=False):
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    # Flush before the rename: on FAT the rename can otherwise reach the disk
    # before the data, leaving a truncated kernel or BOOTX64.EFI on power loss.
    with open(source, "rb") as src, open(dest + ".tmp", "wb") as tmp:
        shutil.copyfileobj(src, tmp)
        tmp.flush()
        os.fsync(tmp.fileno())
    os.replace(dest + ".tmp", dest)


def current_generation() -> int:
    target = os.readlink(PROFILE)
    match = re.fullmatch(r"system-(\d+)-link", os.path.basename(target))
    if not match:
        raise RuntimeError(f"unexpected system profile target: {target}")
    return int(match.group(1))


def generations() -> List[int]:
    # The system-N-link symlinks are the generations (what nix-env
    # --list-generations reads), without needing the profile lock.
    links = os.listdir(os.path.dirname(PROFILE))
    gens = sorted(int(m.group(1)) for m in (re.fullmatch(r"system-(\d+)-link", l) for l in links) if m)
    limit = cfg("maxGenerations")
    return gens[-limit:] if limit else gens


def bootspec(gen: int, spec: Optional[str] = None) -> Dict[str, Any]:
    path = f"{PROFILE}-{gen}-link"
    if spec is not None:
        path = os.path.join(path, "specialisation", spec)
    with open(os.path.join(path, "boot.json")) as f:
        return json.load(f)


def generation_date(gen: int) -> str:
    stat = os.stat(f"{PROFILE}-{gen}-link", follow_symlinks=False)
    return datetime.datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M")


class Installer:
    def __init__(self) -> None:
        self.esp = cfg("efiMountPoint")
        self.rel = "EFI/BOOT" if cfg("efiRemovable") else "EFI/refind"
        self.dir = os.path.join(self.esp, self.rel)

    def esp_path(self, *parts: str) -> str:
        """Path as rEFInd sees it: from the root of the ESP it booted from."""
        return "/" + "/".join((self.rel,) + parts)

    def copy_store_file(self, store_path: str) -> str:
        real = os.path.realpath(store_path)
        name = f"{os.path.basename(os.path.dirname(real))}-{os.path.basename(real)}"
        install_file(real, os.path.join(self.dir, "kernels", name))
        return self.esp_path("kernels", name)

    def boot_tokens(self, spec: Dict[str, Any]) -> List[str]:
        v1 = spec["org.nixos.bootspec.v1"]
        options = " ".join([f"init={v1['init']}"] + v1["kernelParams"])
        if '"' in options:
            raise RuntimeError(f"kernel parameters contain a double quote: {options}")
        tokens = [f"loader {self.copy_store_file(v1['kernel'])}"]
        if v1.get("initrd"):
            tokens.append(f"initrd {self.copy_store_file(v1['initrd'])}")
        tokens.append(f'options "{options}"')
        return tokens

    def nixos_stanza(self, current: int, gens: List[int]) -> str:
        spec = bootspec(current)
        lines = ['menuentry "NixOS" {', f"    icon {self.esp_path('theme', 'icons', 'os_nixos.png')}"]
        lines += [f"    {t}" for t in self.boot_tokens(spec)]

        def sub(title: str, s: Dict[str, Any]) -> None:
            lines.append(f'    submenuentry "{title}" {{')
            lines.extend(f"        {t}" for t in self.boot_tokens(s))
            lines.append("    }")

        for name in sorted(spec.get("org.nixos.specialisation.v1", {})):
            sub(f"Generation {current} ({name})", bootspec(current, name))
        for gen in sorted((g for g in gens if g != current), reverse=True):
            gspec = bootspec(gen)
            sub(f"Generation {gen} - {generation_date(gen)}", gspec)
            for name in sorted(gspec.get("org.nixos.specialisation.v1", {})):
                sub(f"Generation {gen} ({name})", bootspec(gen, name))
        lines.append("}")
        return "\n".join(lines)

    def windows_stanza(self) -> str:
        win = cfg("windows")
        if not win:
            return ""
        # icon must come before volume: files after volume load from that volume
        return "\n".join([
            f'menuentry "{win["title"]}" {{',
            f"    icon {self.esp_path('theme', 'icons', 'os_win.png')}",
            f"    volume {win['partUuid']}",
            "    loader /EFI/Microsoft/Boot/bootmgfw.efi",
            "}",
        ])

    def install_theme(self, current: int) -> None:
        theme = cfg("themePath")
        for name in os.listdir(os.path.join(theme, "icons")):
            install_file(os.path.join(theme, "icons", name), os.path.join(self.dir, "theme", "icons", name))
        for name in ("background.png", "selection_big.png", "selection_small.png"):
            install_file(os.path.join(theme, name), os.path.join(self.dir, "theme", name))
        install_file(cfg("fontPath"), os.path.join(self.dir, "theme", "font.png"))

        # rEFInd's stock icons as the fallback "icons" directory: a built-in
        # icon missing from both icons_dir and icons is drawn by DummyImage,
        # which overruns its buffer at sizes under 32 (e.g. the mouse pointer).
        stock = os.path.join(cfg("refindPath"), "share", "refind", "icons")
        for name in os.listdir(stock):
            install_file(os.path.join(stock, name), os.path.join(self.dir, "icons", name))

        with tempfile.TemporaryDirectory() as tmp:
            svg, png = os.path.join(tmp, "os_nixos.svg"), os.path.join(tmp, "os_nixos.png")
            with open(svg, "w") as f:
                f.write(badge_svg(open(os.path.join(theme, "os_nixos.svg")).read(), current))
            subprocess.check_call([
                os.path.join(cfg("resvgPath"), "bin", "resvg"), "--skip-system-fonts",
                "--use-fonts-dir", cfg("fontDir"), "-w", "256", "-h", "256", svg, png,
            ])
            install_file(png, os.path.join(self.dir, "theme", "icons", "os_nixos.png"))

    def write_config(self, current: int, gens: List[int]) -> None:
        # NixOS: null waits, 0 boots at once. rEFInd: 0 waits, -1 boots at once.
        timeout = cfg("timeout")
        timeout = 0 if timeout is None else (-1 if timeout == 0 else timeout)
        globals_ = "\n".join([
            "# Generated by modules/boot/refind - edits are overwritten on rebuild.",
            f"timeout {timeout}",
            "use_nvram false",
            "resolution max",
            "scanfor manual",
            "showtools " + ", ".join(cfg("tools")),
            "hideui editor, badges",
            "icons_dir theme/icons",
            "banner theme/background.png",
            "banner_scale fillscreen",
            "font theme/font.png",
            "big_icon_size 256",
            "small_icon_size 96",
            "selection_big theme/selection_big.png",
            "selection_small theme/selection_small.png",
            "default_selection 1",
        ])
        stanzas = [self.nixos_stanza(current, gens), self.windows_stanza()]
        conf = "\n\n".join([globals_] + [s for s in stanzas if s]) + "\n"
        path = os.path.join(self.dir, "refind.conf")
        owned.add(os.path.normcase(path))
        with open(path + ".tmp", "w") as f:
            f.write(conf)
            f.flush()
            os.fsync(f.fileno())
        os.replace(path + ".tmp", path)

    def install_binary(self) -> None:
        efi = os.path.join(cfg("refindPath"), "share", "refind", "refind_x64.efi")
        name = "BOOTX64.EFI" if cfg("efiRemovable") else "refind_x64.efi"
        install_file(efi, os.path.join(self.dir, name))
        if cfg("canTouchEfiVariables") and not cfg("efiRemovable"):
            register_nvram_entry(self.esp, f"\\EFI\\refind\\{name}")

    def install_shell(self) -> None:
        # One of the paths rEFInd's shell tool looks for
        dest = os.path.join(self.esp, "EFI", "tools", "shellx64.efi")
        if cfg("shellPath"):
            install_file(cfg("shellPath"), dest)
        elif os.path.exists(dest):
            print(f"removing {dest} (bootloader.refind.shell is off)")
            os.remove(dest)

    def remove_stale(self) -> None:
        for sub in ("kernels", "theme", "icons"):
            for root, _, files in os.walk(os.path.join(self.dir, sub)):
                for name in files:
                    path = os.path.join(root, name)
                    if os.path.normcase(path) not in owned:
                        print(f"removing stale boot file {path}")
                        os.remove(path)

    def run(self) -> None:
        current = current_generation()
        gens = generations()
        if current not in gens:
            gens.append(current)
        os.makedirs(self.dir, exist_ok=True)
        self.install_theme(current)
        self.write_config(current, gens)
        sync_esp()  # everything the new menu needs is on disk before the binary changes
        self.install_binary()
        self.install_shell()
        self.remove_stale()


def badge_svg(svg: str, generation: int) -> str:
    """Fill the os_nixos build badge: flake commit, generation, pill width."""
    rev, dirty = cfg("flakeRev"), cfg("flakeRevDirty")
    markup = rev + ('<tspan fill="#ffb454">*</tspan>' if dirty else "")
    gen = str(generation)
    # JetBrains Mono at font-size 20 advances 12px per glyph: rev, " · ", "#", gen
    width = 12 * (len(rev) + (1 if dirty else 0) + 3 + 1 + len(gen)) + 24
    svg, n1 = re.subn(r'(<tspan id="flake-rev">).*?(</tspan><tspan fill="#595959">)',
                      lambda m: m.group(1) + markup + m.group(2), svg)
    svg, n2 = re.subn(r'(<tspan id="generation">)[^<]*(</tspan>)', rf"\g<1>{gen}\g<2>", svg)
    svg, n3 = re.subn(r'<rect id="build-badge" x="[^"]*" y="212" width="[^"]*"',
                      f'<rect id="build-badge" x="{128 - width / 2:g}" y="212" width="{width}"', svg)
    if (n1, n2, n3) != (1, 1, 1):
        raise RuntimeError("os_nixos.svg no longer has the build badge slots this installer fills")
    return svg


def register_nvram_entry(esp: str, loader: str) -> None:
    efibootmgr = os.path.join(cfg("efibootmgrPath"), "bin", "efibootmgr")
    if re.search(r"Boot[0-9A-Fa-f]{4}\*? rEFInd\b", subprocess.check_output([efibootmgr], universal_newlines=True)):
        return
    with open("/proc/self/mounts") as mounts:
        part = next(line.split()[0] for line in mounts if line.split()[1] == os.path.realpath(esp))
    part = os.path.realpath(part)
    disk = "/dev/" + os.path.basename(os.path.dirname(os.path.realpath(f"/sys/class/block/{os.path.basename(part)}")))
    number = open(f"/sys/class/block/{os.path.basename(part)}/partition").read().strip()
    subprocess.check_call([efibootmgr, "-c", "-d", disk, "-p", number, "-l", loader, "-L", "rEFInd"])


def sync_esp() -> None:
    # FAT has little crash recovery: flush the ESP at each step that matters
    fd = os.open(cfg("efiMountPoint"), os.O_RDONLY)
    try:
        if CDLL("libc.so.6").syncfs(fd) != 0:
            print(f"could not sync {cfg('efiMountPoint')}", file=sys.stderr)
    finally:
        os.close(fd)


def main() -> None:
    try:
        Installer().run()
    finally:
        sync_esp()


if __name__ == "__main__":
    main()
