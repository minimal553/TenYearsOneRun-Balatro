"""Safety properties for the isolated, real-engine QA launcher."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('qa_launch', ROOT / 'tools/runtime_qa/launch.py')
qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qa)


class LauncherSafetyTests(unittest.TestCase):
    def test_run_names_cannot_escape_qa_root(self):
        for name in ('../outside', '/outside', 'C:\\outside', 'a/b', '..', ''):
            with self.subTest(name=name), self.assertRaises(ValueError):
                qa.resolve_run(ROOT, name)

    def test_legacy_seed_is_only_the_authorized_sibling_project(self):
        self.assertEqual(qa.resolve_seed_run(ROOT, 'v0.4-dev:known-qa').parent,
                         (ROOT.parent / 'v0.4-dev/qa-runs').resolve())
        self.assertEqual(qa.resolve_seed_run(ROOT, 'v0.5-dev:known-qa').parent,
                         (ROOT.parent / 'v0.5-dev/qa-runs').resolve())
        self.assertEqual(qa.resolve_seed_run(ROOT, 'v0.6-dev:known-qa').parent,
                         (ROOT.parent / 'v0.6-dev/qa-runs').resolve())
        for token in ('v0.4-dev:../../Balatro', 'v0.3-dev:unknown', 'C:\\saves', '../old'):
            with self.subTest(token=token), self.assertRaises(ValueError):
                qa.resolve_seed_run(ROOT, token)

    def test_child_environment_does_not_mutate_parent(self):
        before = dict(os.environ)
        run = ROOT / 'qa-runs' / 'unit-only'
        env = qa.child_environment(run, 'smoke')
        self.assertEqual(dict(os.environ), before)
        self.assertEqual(env['APPDATA'], str(run / 'userdata'))
        self.assertEqual(env['LOVELY_MOD_DIR'], str(run / 'Mods'))
        self.assertEqual(env['TYG_QA_EXPECT_SAVE'], str(run / 'userdata' / 'Balatro'))
        self.assertEqual(bytes.fromhex(env['TYG_QA_EXPECT_SAVE_HEX']).decode('utf-8'),
                         str(run / 'userdata' / 'Balatro'))

    def test_existing_run_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            run = project / 'qa-runs' / 'existing'
            run.mkdir(parents=True)
            marker = run / 'keep.txt'
            marker.write_text('keep', encoding='utf-8')
            with self.assertRaises(FileExistsError):
                qa.create_run(project, 'existing')
            self.assertEqual(marker.read_text(encoding='utf-8'), 'keep')

    def test_report_requires_real_nonempty_screenshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)
            report = {'status': 'passed', 'screenshots': ['menu.png']}
            with self.assertRaises(RuntimeError):
                qa.verify_report(run, report)

    def test_extra_mod_copy_omits_personal_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'source/TenYearsOneHand'
            source.mkdir(parents=True)
            for name in qa.EXTRA_FILES['TenYearsOneHand']:
                (source / name).write_text('{"id":"fixture"}' if name=='json.json' else '-- public code', encoding='utf-8')
            (source / 'config.lua').write_text('PRIVATE_SENTINEL', encoding='utf-8')
            (source / 'profile.json').write_text('PRIVATE_SENTINEL', encoding='utf-8')
            target = Path(tmp) / 'Mods'
            target.mkdir()
            result = qa.copy_extra_mod(source, target)
            self.assertEqual(set(result['files']), set(qa.EXTRA_FILES['TenYearsOneHand']))
            self.assertFalse((target / 'TenYearsOneHand/config.lua').exists())
            self.assertFalse((target / 'TenYearsOneHand/profile.json').exists())


if __name__ == '__main__':
    unittest.main()
