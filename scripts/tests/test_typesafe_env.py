import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "typesafe_env", Path(__file__).parents[1] / "with-typesafe-env.py"
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)

update_spec = importlib.util.spec_from_file_location(
    "typesafe_update", Path(__file__).parents[1] / "set-typesafe-api-key.py"
)
update = importlib.util.module_from_spec(update_spec)
update_spec.loader.exec_module(update)


class TypeSafeEnvTests(unittest.TestCase):
    def test_reads_only_typesafe_key_and_handles_env_quoting(self):
        text = "OTHER_KEY=other\nTYPESAFE_API_KEY='example$key' # comment\n"
        self.assertEqual(helper.load_key(text), "example$key")

    def test_missing_empty_or_malformed_key_is_rejected(self):
        for text in ["OTHER_KEY=x", "TYPESAFE_API_KEY=", "TYPESAFE_API_KEY=a b",
                     "TYPESAFE_API_KEY='", "TYPESAFE_API_KEY='' "]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                helper.load_key(text)

    def test_key_update_preserves_other_credentials_and_replaces_duplicates(self):
        text = "OTHER_KEY='preserve me'\nTYPESAFE_API_KEY=old\nTYPESAFE_API_KEY=duplicate\n"
        updated = update.replace_key(text, "example'key$with spaces")
        self.assertIn("OTHER_KEY='preserve me'\n", updated)
        self.assertEqual(updated.count("TYPESAFE_API_KEY="), 1)
        self.assertEqual(helper.load_key(updated), "example'key$with spaces")


if __name__ == "__main__":
    unittest.main()
