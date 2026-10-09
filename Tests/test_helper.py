"""Exercise the production shell logic against disposable paths and a fake pmset.

Only the test copy gets substituted binaries. The shipping helper has fixed paths
and accepts no environment override that could execute user code as root.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class HelperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="lidkeep-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / "state"
        self.state.mkdir(mode=0o700)
        self.data = self.root / "power.json"
        self.initial = {"ac": 17, "battery": 8, "disabled": 0, "calls": []}
        self.data.write_text(json.dumps(self.initial))
        pmset = self.root / "pmset"
        pmset.write_text("#!/usr/bin/env python3\n" + f"DATA={str(self.data)!r}\n" + '''
import json, sys
from pathlib import Path
p=Path(DATA); data=json.loads(p.read_text()); a=sys.argv[1:]
if a == ['-g', 'custom']:
    print('Battery Power:\\n sleep %s\\nAC Power:\\n sleep %s' % (data['battery'],data['ac']))
elif a == ['-g']:
    print('System-wide power settings:\\n SleepDisabled %s' % data['disabled'])
else:
    data['calls'].append(a)
    if a[:2] == ['-a','disablesleep']: data['disabled']=int(a[2])
    elif a[:2] == ['-c','sleep']: data['ac']=int(a[2])
    elif a[:2] == ['-b','sleep']: data['battery']=int(a[2])
    else: sys.exit(2)
    p.write_text(json.dumps(data))
''')
        pmset.chmod(0o755)
        fake_id = self.root / "id"
        fake_id.write_text("#!/bin/bash\necho 0\n"); fake_id.chmod(0o755)
        fake_stat = self.root / "stat"
        fake_stat.write_text("#!/usr/bin/env python3\nimport os,sys\ns=os.stat(sys.argv[-1]); print('0:%o' % (s.st_mode & 0o777))\n")
        fake_stat.chmod(0o755)
        script = (ROOT / "Resources/pmset-helper.sh").read_text()
        script = script.replace("/Library/Application Support/LidKeep", str(self.state))
        for original, fake in [("/usr/bin/pmset", pmset), ("/usr/bin/id", fake_id), ("/usr/bin/stat", fake_stat)]:
            script = script.replace(original, str(fake))
        self.helper = self.root / "helper.sh"
        self.helper.write_text(script)

    def call(self, *args, ok=True):
        r = subprocess.run(["/bin/bash", str(self.helper), *args], capture_output=True, text=True)
        self.assertEqual(r.returncode == 0, ok, r.stderr)
        return r

    def power(self): return json.loads(self.data.read_text())

    def test_suspend_survives_watchdog(self):
        self.call("lid-on")
        self.assertEqual(self.power()["disabled"], 1)
        self.call("suspend")
        self.call("hold")
        self.assertEqual(self.power()["disabled"], 0)
        self.assertIn("suspended=1", self.call("status").stdout)
        self.call("lid-on"); self.call("hold")
        self.assertEqual(self.power()["disabled"], 1)

    def test_snapshot_restore_preserves_unusual_original_timers(self):
        self.call("lid-on")
        self.call("sleep-both", "0", "30")
        self.call("lid-off")
        self.call("restore-system")
        result = self.power()
        for key in ("ac", "battery", "disabled"):
            self.assertEqual(result[key], self.initial[key])
        self.assertFalse((self.state / "original-settings").exists())
        self.call("hold")
        self.assertEqual(self.power()["disabled"], 0)

    def test_reject_arguments_without_side_effects(self):
        for args in [("lid-on", "extra"), ("sleep-both", "0", "5", "extra"), ("sleep-both", "2", "5"), ("sleep-both", "0;whoami", "1"), ("unknown",), ()]:
            self.call(*args, ok=False)
        self.assertEqual(self.power(), self.initial)
        self.assertEqual(list(self.state.iterdir()), [])

    def test_symlink_and_writable_state_rejected(self):
        other = self.root / "other"; other.write_text("unchanged")
        (self.state / "lid-awake-wanted").symlink_to(other)
        self.call("lid-on", ok=False)
        self.assertEqual(other.read_text(), "unchanged")
        (self.state / "lid-awake-wanted").unlink()
        self.state.chmod(0o777)
        self.call("lid-on", ok=False)
        self.assertEqual(self.power(), self.initial)

    def test_all_allowed_delay_pairs(self):
        for ac in (0, 1, 5, 10, 30):
            for battery in (0, 1, 5, 10, 30):
                self.call("sleep-both", str(ac), str(battery))
                self.assertEqual((self.power()["ac"], self.power()["battery"]), (ac, battery))
        self.call("restore-system")
        self.assertEqual(self.power()["ac"], self.initial["ac"])

    def test_snapshot_preserves_preexisting_disabled_sleep(self):
        original = self.initial.copy(); original["disabled"] = 1
        self.data.write_text(json.dumps(original))
        self.call("lid-off"); self.call("restore-system")
        self.assertEqual(self.power()["disabled"], 1)

    def test_restore_serializes_with_inflight_watchdog(self):
        self.call("lid-on")
        marker = self.root / "holding"
        pmset = self.root / "pmset"
        code = pmset.read_text().replace("else:\n    data['calls']", f"else:\n    if a == ['-a','disablesleep','1']:\n        Path({str(marker)!r}).touch()\n        import time; time.sleep(0.25)\n    data['calls']")
        pmset.write_text(code)
        process = subprocess.Popen(["/bin/bash", str(self.helper), "hold"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        import time
        deadline = time.monotonic() + 2
        while not marker.exists() and time.monotonic() < deadline: time.sleep(0.01)
        self.assertTrue(marker.exists(), "Watchdog did not enter the simulated slow write")
        self.call("restore-system")
        _, stderr = process.communicate(timeout=3)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(self.power()["disabled"], self.initial["disabled"])
        self.assertFalse((self.state / "lid-awake-wanted").exists())

    def test_corrupt_snapshot_never_executed(self):
        backup = self.state / "original-settings"
        backup.write_text("$(touch injected)\n1\n0\n"); backup.chmod(0o600)
        self.call("restore-system", ok=False)
        self.assertEqual(self.power(), self.initial)

if __name__ == "__main__": unittest.main()
