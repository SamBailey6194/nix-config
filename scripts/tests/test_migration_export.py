import base64
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('migration_export', Path(__file__).parents[1] / 'export-ubuntu-migration-secrets.py')
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


class MigrationExportTests(unittest.TestCase):
    def setUp(self):
        self.key = base64.b64encode(bytes(range(32))).decode()
        self.configuration = f'[Interface]\nPrivateKey = {self.key}\n[Peer]\nPublicKey = {exporter.SERVER_PUBLIC_KEY}\nPresharedKey = {self.key}\n'
        self.environment = 'SD_SMTP_USER=test@example.invalid\nSD_SMTP_PASS=fake-only\nSD_MAIL_TO=recipient@example.invalid\nSD_HEARTBEAT_URL=https://hc-ping.com/fake-only\nSD_USERS=sam-dev\nSD_LOG_DIR=/obsolete/ubuntu/path\n'

    def test_export_keeps_only_credentials_and_preserves_quoted_values(self):
        payload = exporter.export_payload(self.configuration, self.environment.replace('fake-only\nSD_MAIL_TO', '\"fake with spaces\"\nSD_MAIL_TO'))
        self.assertEqual(set(payload), {'arwyn-private.key', 'arwyn-psk.key', 'squid-digest.env'})
        self.assertIn('SD_SMTP_PASS="fake with spaces"', payload['squid-digest.env'])
        self.assertNotIn('SD_USERS', payload['squid-digest.env'])
        self.assertNotIn('/obsolete', payload['squid-digest.env'])

    def test_missing_accountability_credential_is_rejected(self):
        with self.assertRaises(ValueError):
            exporter.export_payload(self.configuration, self.environment.replace('SD_SMTP_PASS=fake-only\n', ''))

    def test_wrong_server_peer_is_rejected(self):
        with self.assertRaises(ValueError):
            exporter.export_payload(self.configuration.replace(exporter.SERVER_PUBLIC_KEY, self.key), self.environment)

    def test_malformed_wireguard_key_is_rejected(self):
        with self.assertRaises(ValueError):
            exporter.export_payload(self.configuration.replace('PresharedKey = ' + self.key, 'PresharedKey = invalid!'), self.environment)


if __name__ == '__main__':
    unittest.main()
