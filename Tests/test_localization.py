"""Prevent missing translations and unsafe format strings in either language."""
import collections
import json
import pathlib
import re
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.tables = {}
        for language in ("en", "zh-Hans"):
            path = ROOT / "Resources" / (language + ".lproj") / "Localizable.strings"
            self.tables[language] = json.loads(subprocess.check_output(
                ["plutil", "-convert", "json", "-o", "-", str(path)], text=True))

    def test_every_application_message_has_both_translations(self):
        keys = set()
        for source in (ROOT / "Sources").glob("*.swift"):
            keys.update(re.findall(r'L\.(?:text|format)\("([^"\\]*)"', source.read_text()))
        for language, table in self.tables.items():
            self.assertFalse(keys - table.keys(), f"Missing {language}: {keys - table.keys()}")
            self.assertTrue(all(table.values()))
        self.assertEqual(self.tables["en"].keys(), self.tables["zh-Hans"].keys())

    def test_format_arguments_match_between_languages(self):
        for key, english in self.tables["en"].items():
            chinese = self.tables["zh-Hans"][key]
            # All application formats use %@ or %d; compare multiplicity and order.
            self.assertEqual(re.findall(r"%[@d]", english), re.findall(r"%[@d]", chinese), key)
            self.assertEqual(english.count("%"), chinese.count("%"), key)

    def test_no_duplicate_keys(self):
        for language in self.tables:
            source = (ROOT / "Resources" / (language + ".lproj") / "Localizable.strings").read_text()
            keys = re.findall(r'^"([^"\\]*)"\s*=', source, re.MULTILINE)
            duplicates = [key for key, count in collections.Counter(keys).items() if count > 1]
            self.assertEqual(duplicates, [], language)

    def test_bilingual_resources_are_in_the_app(self):
        bundle = ROOT / "dist/LidKeep.app/Contents/Resources"
        if not bundle.exists():
            self.skipTest("Build the app first to check bundled translations.")
        for language in self.tables:
            bundled = bundle / (language + ".lproj") / "Localizable.strings"
            source = ROOT / "Resources" / (language + ".lproj") / "Localizable.strings"
            self.assertEqual(bundled.read_bytes(), source.read_bytes())
