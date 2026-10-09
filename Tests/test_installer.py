"""Validate the actual sudoers-generation block without running root installation."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class InstallerTests(unittest.TestCase):
    def test_exact_sudoers_combinations(self):
        text = (ROOT / 'Resources/install-helper.sh').read_text()
        start = text.index('{\n  for command')
        end = text.index('\nchown root:wheel "$sudoers_tmp"', start)
        block = text[start:end]
        with tempfile.TemporaryDirectory(prefix='lidkeep-sudoers-') as temp:
            rule = Path(temp) / 'rules'
            env = {'PATH': '/usr/bin:/bin', 'account': 'lidkeep_test',
                   'dest': '/Library/PrivilegedHelperTools/com.ylc.lidkeep.helper', 'sudoers_tmp': str(rule)}
            subprocess.run(['/bin/bash', '-eu', '-c', block], env=env, check=True)
            result = subprocess.run(['/usr/sbin/visudo', '-cf', str(rule)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = rule.read_text().splitlines()
            self.assertEqual(len(lines), 32)
            self.assertEqual(len(set(lines)), 32)
            for line in lines:
                self.assertNotIn('*', line)
                self.assertNotIn('NOPASSWD: ALL', line)
            for ac in (0, 1, 5, 10, 30):
                for battery in (0, 1, 5, 10, 30):
                    self.assertTrue(any(line.endswith(f' sleep-both {ac} {battery}') for line in lines))

if __name__ == '__main__': unittest.main()
