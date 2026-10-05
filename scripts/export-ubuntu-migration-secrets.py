#!/usr/bin/env python3
"""Manually run as root on Ubuntu before its final offline backup.

Export only the existing arwyn VPN keys and accountability environment. Never
print credentials, contact remote services, or overwrite an earlier export.
"""
import base64
import configparser
import os
from pathlib import Path
import re
import subprocess

DESTINATION = Path('/etc/nixos-migration')
SERVER_PUBLIC_KEY = 'Gkrr+dIpIsUfqFcKKYodW8mi1yaAVv+QuhJ8ea7oBRk='
DESKTOP_PUBLIC_KEY = 'OCftpGqf+GX1Ia4lg8tcp9/Z5/nL3dpTIlmhs1h8uH8='


def export_payload(configuration, environment):
    sections = re.split(r'(?m)^\[Peer\]\s*$', configuration)
    interface = configparser.ConfigParser(interpolation=None)
    interface.read_string(sections[0])
    private = interface['Interface']['PrivateKey'].strip()
    peers = []
    for section in sections[1:]:
        parser = configparser.ConfigParser(interpolation=None)
        parser.read_string('[Peer]\n' + section)
        if parser['Peer'].get('PublicKey', '').strip() == SERVER_PUBLIC_KEY:
            peers.append(parser['Peer'])
    if len(peers) != 1:
        raise ValueError('Expected exactly one arwyn-1 peer; export refused')
    psk = peers[0]['PresharedKey'].strip()
    for key in (private, psk):
        if len(base64.b64decode(key, validate=True)) != 32:
            raise ValueError('Invalid WireGuard key length')
    names = ('SD_SMTP_USER', 'SD_SMTP_PASS', 'SD_MAIL_TO', 'SD_HEARTBEAT_URL')
    values = {}
    for line in environment.splitlines():
        match = re.match(r'^\s*(SD_[A-Z_]+)=(.+)$', line)
        if match and match[1] in names:
            if not match[2].strip().strip('\"\''):
                raise ValueError('Empty accountability credential')
            values[match[1]] = match[2]
    if set(values) != set(names):
        raise ValueError('Missing accountability credentials; export refused')
    return {
        'arwyn-private.key': private + '\n',
        'arwyn-psk.key': psk + '\n',
        'squid-digest.env': ''.join(f'{name}={values[name]}\n' for name in names),
    }


def main():
    if os.geteuid() != 0:
        raise SystemExit('Run manually with sudo on Ubuntu before backup')
    os.umask(0o077)
    config = subprocess.run(['wg', 'showconf', 'wg0'], check=True,
                            capture_output=True, text=True).stdout
    payload = export_payload(config, Path('/etc/squid-digest/env').read_text())
    public = subprocess.run(['wg', 'pubkey'], input=payload['arwyn-private.key'],
                            check=True, capture_output=True, text=True).stdout.strip()
    if public != DESKTOP_PUBLIC_KEY:
        raise SystemExit('Current VPN key differs from the recorded server peer; stop and check it')
    if DESTINATION.is_symlink():
        raise SystemExit('Export directory is a symlink; refused')
    if DESTINATION.exists() and (DESTINATION.stat().st_uid != 0 or DESTINATION.stat().st_mode & 0o077):
        raise SystemExit('Existing export directory must be owned by root with mode 0700')
    DESTINATION.mkdir(mode=0o700, exist_ok=True)
    if any((DESTINATION / name).exists() or (DESTINATION / name).is_symlink() for name in payload):
        raise SystemExit('Earlier export exists; preserve it and review before exporting again')
    for name, contents in payload.items():
        path = DESTINATION / name
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as output:
            output.write(contents)
    print('Exported 3 credential files into /etc/nixos-migration (root-only).')
    print('Include Ubuntu root in the encrypted offline backup. No remote services were contacted.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, configparser.Error, subprocess.CalledProcessError):
        raise SystemExit('Export validation failed; no credentials were printed. Check the existing VPN and environment.')
