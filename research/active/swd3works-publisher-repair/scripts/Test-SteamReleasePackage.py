"""Offline regression for real packaged manifests and release snapshots."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import SteamReleasePackage as release

parser = argparse.ArgumentParser()
parser.add_argument('fixture', type=Path)
args = parser.parse_args()
fixture = args.fixture.resolve(strict=True)
workspace = Path(__file__).resolve().parents[4]
work = workspace / '.work'
work.mkdir(exist_ok=True)


class ReleasePackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='release-package-tests-', dir=work)
        self.root = Path(self.temp.name).resolve()
        assert self.root.is_relative_to(work.resolve())
        self.package = self.root / fixture.name
        self.package.write_bytes(fixture.read_bytes())

    def tearDown(self):
        assert self.root.is_relative_to(work.resolve())
        self.temp.cleanup()

    def draft(self, **changes):
        value = dict(Package=str(self.package), Title='測試 <標題>', Description='多行\n內容',
                     ChangeNote='更新說明', WorkshopId='123')
        value.update(changes)
        path = self.root / 'draft.json'
        path.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
        return path

    def test_real_package_snapshot_stays_unchanged_after_source_edit(self):
        actual = release.inspect(self.package)
        with contextlib.redirect_stdout(io.StringIO()):
            release.prepare(self.draft(), self.root / 'release')
        self.package.write_bytes(b'changed source')
        snapshot = self.root / 'release' / 'content' / fixture.name
        self.assertEqual(release.inspect(snapshot), actual)
        plan = json.loads((self.root / 'release' / 'plan.json').read_text(encoding='utf-8'))
        self.assertEqual(plan['Version'], actual['Version'])
        self.assertEqual(plan['Schema'], 3)
        self.assertEqual(plan['Title'], '測試 <標題>')

    def test_declared_version_cannot_override_package_version(self):
        with self.assertRaisesRegex(ValueError, 'differs'):
            release.prepare(self.draft(Version='2147483647.0'), self.root / 'release')
        self.assertFalse((self.root / 'release').exists())

    def test_broken_package_never_becomes_release(self):
        self.package.write_bytes(b'SMOD\x04\x00\x00\x00incomplete')
        with self.assertRaisesRegex(ValueError, 'frame not found'):
            release.prepare(self.draft(), self.root / 'release')
        self.assertFalse((self.root / 'release').exists())

    def test_existing_release_cannot_be_overwritten(self):
        target = self.root / 'release'
        target.mkdir()
        sentinel = target / 'keep.txt'
        sentinel.write_text('retained', encoding='utf-8')
        with self.assertRaises(FileExistsError):
            release.prepare(self.draft(), target)
        self.assertEqual(sentinel.read_text(encoding='utf-8'), 'retained')

    def test_non_package_is_rejected(self):
        self.package.write_bytes(b'not an archive')
        with self.assertRaisesRegex(ValueError, 'SMOD v4'):
            release.inspect(self.package)


unittest.main(argv=['Test-SteamReleasePackage.py'], verbosity=2)
