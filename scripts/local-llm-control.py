#!/usr/bin/env python3
"""Select and tune one model while retaining the NixOS llama-swap sandbox."""
import argparse
import copy
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = Path('/etc/local-llm/control.json')
RUNTIME = Path('/run/local-llm')
DROPIN = Path('/run/systemd/system/llama-swap.service.d/50-local-model.conf')
# Preserve the registered model, full context and loopback/OpenCode routing.
# Credentials belong in runtime environment files, not CLI flags/config output.
FIXED = {'--host', '--port', '--alias', '-a', '--model', '-m', '--hf-repo',
         '--hf-file', '-hf', '--hf-token', '-hft', '--api-key', '--api-key-file',
         '--ctx-size', '-c', '--fit-ctx', '--parallel', '-np'}


def select_model(base, model, flags):
    if model not in base['settings']['models']:
        raise ValueError(f'Unknown model: {model}. Run just llama-models.')
    for arg in flags:
        if arg.split('=', 1)[0] in FIXED:
            raise ValueError(f'{arg.split("=", 1)[0]} is managed: keep full context, one slot and the OpenCode endpoint')
    settings = copy.deepcopy(base['settings'])
    selected = settings['models'][model]
    selected['cmd'] += (' ' + shlex.join(flags)) if flags else ''
    settings['models'] = {model: selected}
    return settings


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def systemctl(*arguments):
    subprocess.run(['systemctl', *arguments], check=True)


def elevate():
    if os.geteuid() != 0:
        os.execvp('sudo', ['sudo', sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['models', 'plan', 'start', 'stop', 'auto', 'status'])
    parser.add_argument('model', nargs='?')
    parser.add_argument('flags', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    base = json.loads(BASE.read_text())
    model = args.model or base['defaultModel']
    if args.action == 'models':
        for key, entry in base['catalog'].items():
            print(f'{key:24} {entry["contextSize"]:7} tokens  {entry["name"]}')
        return
    if args.action == 'status':
        subprocess.run(['systemctl', 'status', '--no-pager', 'llama-swap'])
        try:
            with urllib.request.urlopen(base['url'] + '/running', timeout=3) as response:
                print(response.read().decode())
        except (urllib.error.URLError, TimeoutError):
            print('Local model endpoint is unavailable.')
        return
    selected = select_model(base, model, args.flags) if args.action in ('start', 'plan') else None
    if args.action == 'plan':
        print(selected['models'][model]['cmd'])
        return
    elevate()
    if args.action == 'start':
        # Write an isolated runtime override; keep the service cache, GPU access,
        # DynamicUser, compute.slice and cgroup memory policy from NixOS.
        atomic_write(RUNTIME / 'config.json', json.dumps(selected, indent=2) + '\n')
        command = f'{base["swapBinary"]} --listen={base["listen"]} --config={RUNTIME}/config.json'
        atomic_write(DROPIN, '[Service]\nExecStart=\nExecStart=' + command + '\n')
        systemctl('daemon-reload')
        systemctl('restart', 'llama-swap')
        for attempt in range(30):
            try:
                with urllib.request.urlopen(base['url'] + '/health', timeout=2) as response:
                    if response.status == 200:
                        break
            except (urllib.error.URLError, TimeoutError):
                if attempt == 29:
                    raise RuntimeError('llama-swap did not become ready; inspect just llama-logs')
                time.sleep(1)
        print(f'Loading {model}; first download/full-context allocation can take time.', flush=True)
        endpoint = base['url'] + '/upstream/' + urllib.parse.quote(model, safe='') + '/health'
        try:
            with urllib.request.urlopen(endpoint, timeout=base['settings']['healthCheckTimeout'] + 30) as response:
                if response.status != 200:
                    raise RuntimeError('Selected model is not healthy')
        except (urllib.error.URLError, TimeoutError):
            raise RuntimeError('Model load failed or timed out; inspect just llama-logs. The service may still be loading.')
        print(f'Ready for OpenCode: llama-cpp/{model} at {base["url"]}/v1')
        return
    systemctl('stop', 'llama-swap')
    DROPIN.unlink(missing_ok=True)
    (RUNTIME / 'config.json').unlink(missing_ok=True)
    systemctl('daemon-reload')
    if args.action == 'auto':
        systemctl('start', 'llama-swap')
        print('Restored the declarative model catalogue and on-demand switching.')
    else:
        print('Local model server stopped; runtime tuning cleared.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
