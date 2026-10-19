import importlib.util
from pathlib import Path
import shlex
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('llm_control', Path(__file__).parents[1] / 'local-llm-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class LocalModelControlTests(unittest.TestCase):
    def setUp(self):
        self.base = {'settings': {'models': {
            'first': {'cmd': 'llama-server --ctx-size 262144 --fit-ctx 262144'},
            'second': {'cmd': 'llama-server --ctx-size 131072'},
        }}}

    def test_only_selected_model_is_served_and_base_is_preserved(self):
        selected = control.select_model(self.base, 'first', ['--threads', '6'])
        self.assertEqual(list(selected['models']), ['first'])
        self.assertIn('--ctx-size 262144', selected['models']['first']['cmd'])
        self.assertIn('--threads 6', selected['models']['first']['cmd'])
        self.assertEqual(len(self.base['settings']['models']), 2)
        self.assertNotIn('--threads', self.base['settings']['models']['first']['cmd'])

    def test_tuning_value_is_one_argument_and_not_shell_code(self):
        literal = 'expert.*=CPU; touch /tmp/should-not-exist'
        selected = control.select_model(self.base, 'first', ['--override-tensor', literal])
        self.assertEqual(shlex.split(selected['models']['first']['cmd'])[-1], literal)

    def test_old_http_limit_is_migrated_without_changing_inference_slots(self):
        entry = self.base['settings']['models']['first']
        entry['concurrencyLimit'] = 1
        entry['cmd'] += ' --parallel 1'
        selected = control.select_model(self.base, 'first', [])
        self.assertEqual(selected['models']['first']['concurrencyLimit'], 10)
        self.assertEqual(selected['models']['first']['cmd'], entry['cmd'])
        self.assertEqual(entry['concurrencyLimit'], 1)

    def test_other_http_limits_are_preserved(self):
        self.base['settings']['models']['first']['concurrencyLimit'] = 3
        selected = control.select_model(self.base, 'first', [])
        self.assertEqual(selected['models']['first']['concurrencyLimit'], 3)

    def test_managed_context_and_endpoint_cannot_be_overridden(self):
        for flag in ['-c', '--ctx-size=4096', '--host', '--hf-token=secret', '-np']:
            with self.subTest(flag=flag), self.assertRaises(ValueError):
                control.select_model(self.base, 'first', [flag])

    def test_unknown_model_is_rejected(self):
        with self.assertRaises(ValueError):
            control.select_model(self.base, 'missing', [])

    def test_elevation_uses_nixos_wrapper_independent_of_path(self):
        arguments = ['local-llm-control', 'start', 'first', '--threads', '6']
        with patch.object(control.os, 'geteuid', return_value=1000), \
                patch.dict(control.os.environ, {'PATH': '/nix/store/unwrapped-sudo/bin'}), \
                patch.object(control.sys, 'argv', arguments), \
                patch.object(control.os, 'execv') as execute:
            control.elevate()
        execute.assert_called_once_with('/run/wrappers/bin/sudo', [
            '/run/wrappers/bin/sudo', control.sys.executable,
            str(Path(control.__file__).resolve()), *arguments[1:],
        ])

    def test_root_does_not_elevate_again(self):
        with patch.object(control.os, 'geteuid', return_value=0), \
                patch.object(control.os, 'execv') as execute:
            control.elevate()
        execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()
