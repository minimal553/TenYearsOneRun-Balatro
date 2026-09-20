"""Launch an owned Balatro process with private APPDATA and private Mods.

Never edits the installed game or production mod. Never discovers or kills
other processes. All generated files live under this project's qa-runs/.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

PROJECT = Path(__file__).resolve().parents[2]
ASSETS = Path(__file__).resolve().parent / 'qa_mod'
EXTRA_FILES = {
    'TenYearsOneHand': ['TenYearsOneHand.lua', 'rules.lua', 'json.json'],
    'DragonFantasyCity': ['DragonFantasyCity.lua', 'json.json', 'src/deck.lua',
                         'src/hooks.lua', 'src/jokers.lua', 'src/util.lua']
                         + [f'assets/{scale}/{name}.png' for scale in ('1x', '2x')
                            for name in ('Decks', 'Jokers', 'modicon')],
}


def resolve_run(project, name):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}', name):
        raise ValueError('Run name must be a simple identifier, not a path')
    project = project.resolve()
    parent = (project / 'qa-runs').resolve()
    if parent.parent != project or parent.name != 'qa-runs':
        raise ValueError('qa-runs may not redirect outside its designated project path')
    run = (parent / name).resolve()
    if run.parent != parent:
        raise ValueError('Run escapes qa-runs')
    protected = (Path(os.environ.get('APPDATA', '')) / 'Balatro').resolve()
    if run == protected or protected in run.parents:
        raise ValueError('Refusing a run inside the real Balatro userdata')
    return run


def create_run(project, name):
    run = resolve_run(project, name)
    run.mkdir(parents=True, exist_ok=False)
    return run


def resolve_seed_run(project, token):
    # Only the explicitly authorized previous development project's own QA
    # fixtures may cross the project boundary. Never accepts a save-file path.
    for previous in ('v0.4-dev', 'v0.5-dev'):
        if token.startswith(previous + ':'):
            return resolve_run(project.resolve().parent / previous, token.split(':', 1)[1])
    return resolve_run(project, token)


def child_environment(run, scenario):
    env = dict(os.environ)
    env.update(APPDATA=str(run / 'userdata'), LOCALAPPDATA=str(run / 'localdata'),
               LOVELY_MOD_DIR=str(run / 'Mods'), TYG_QA_EXPECT_SAVE=str(run / 'userdata' / 'Balatro'),
               TYG_QA_EXPECT_MODS=str(run / 'Mods'), TYG_QA_RUN=run.name,
               TYG_QA_SCENARIO=scenario, SDL_VIDEO_WINDOW_POS='-32000,-32000')
    # Lua 5.1 os.getenv uses the Windows narrow CRT; LÖVE uses UTF-16 APPDATA.
    # Carry comparison values as ASCII hex so Chinese project paths compare
    # against the engine's UTF-8 directory strings without lossy conversion.
    env['TYG_QA_EXPECT_SAVE_HEX'] = str(run / 'userdata' / 'Balatro').encode('utf-8').hex()
    env['TYG_QA_EXPECT_MODS_HEX'] = str(run / 'Mods').encode('utf-8').hex()
    return env


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def digest_tree(path):
    return {file.relative_to(path).as_posix(): hashlib.sha256(file.read_bytes()).hexdigest()
            for file in sorted(path.rglob('*')) if file.is_file()}


def copy_extra_mod(source, mods_dir):
    """Explicit code/art allowlist: never opens or copies config/profile files."""
    selected = EXTRA_FILES.get(source.name)
    if selected is None:
        raise ValueError('Unreviewed extra mod: ' + source.name)
    target = mods_dir / source.name
    target.mkdir(exist_ok=False)
    for relative in selected:
        original = source / relative
        if not original.is_file() or original.is_symlink():
            raise ValueError('Missing/non-regular approved mod file: ' + str(original))
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, destination)
    metadata = json.loads((target / 'json.json').read_text(encoding='utf-8'))
    return {'name': source.name, 'id': metadata['id'], 'files': digest_tree(target),
            'configuration': 'personal config.lua omitted; built-in code defaults only'}


def verify_report(run, report):
    if report.get('status') != 'passed':
        raise RuntimeError('Engine probe failed: ' + str(report.get('error', report.get('status'))))
    screenshots = report.get('screenshots', [])
    if not screenshots:
        raise RuntimeError('Engine returned no screenshot evidence')
    savedir = (run / 'userdata' / 'Balatro').resolve()
    for name in screenshots:
        image = (savedir / name).resolve()
        if savedir not in image.parents or not image.is_file() or image.stat().st_size < 100:
            raise RuntimeError('Missing/unsafe/empty engine screenshot: ' + str(image))


def run_probe(game, smods, mod, name, scenario, timeout, extra_mods=(), seed_qa_run=None):
    for source in (game, game.parent / 'love.dll', game.parent / 'version.dll', smods, mod):
        if not source.exists():
            raise FileNotFoundError(source)
    run = create_run(PROJECT, name)
    (run / 'userdata' / 'Balatro').mkdir(parents=True)
    (run / 'localdata').mkdir()
    (run / 'Mods').mkdir()
    if seed_qa_run:
        if scenario != 'reload':
            raise ValueError('A saved QA fixture may only seed the reload scenario')
        previous = resolve_seed_run(PROJECT, seed_qa_run)
        if not (previous / 'launch.json').is_file():
            raise ValueError('Source is not an owned recorded QA run')
        for relative in ('settings.jkr', '1/save.jkr', '1/profile.jkr', '1/meta.jkr',
                         'runtime-qa-reload-expected.json'):
            target = run / 'userdata/Balatro' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(previous / 'userdata/Balatro' / relative, target)
    shutil.copytree(smods, run / 'Mods' / 'smods', ignore=shutil.ignore_patterns('.git', '__pycache__'))
    shutil.copytree(mod, run / 'Mods' / 'TenYearsNineGrid', ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copytree(ASSETS, run / 'Mods' / 'TygRuntimeQA')
    extras = [copy_extra_mod(source, run / 'Mods') for source in extra_mods]
    manifest = {'run': name, 'scenario': scenario, 'started_utc': datetime.now(timezone.utc).isoformat(),
                'game': str(game), 'game_sha256': hashlib.sha256(game.read_bytes()).hexdigest(),
                'mod_source': str(mod), 'mod_sha256': digest_tree(run / 'Mods' / 'TenYearsNineGrid'),
                'seed_qa_run': seed_qa_run,
                'extra_mods': extras,
                'save_directory': str(run / 'userdata' / 'Balatro'), 'mods_directory': str(run / 'Mods'),
                'isolation': 'child environment only; QA Steam branch disabled; offscreen real renderer'}
    write_json(run / 'launch.json', manifest)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    phases = [scenario, 'reload'] if scenario in ('cycle', 'combo', 'preset1', 'preset9') else [scenario]
    manifest['processes'] = []
    for phase in phases:
        process_record = {'phase': phase}
        environment = child_environment(run, phase)
        environment['TYG_QA_EXPECT_EXTRA_IDS'] = ','.join(extra['id'] for extra in extras)
        with (run / ('process-output-' + phase + '.log')).open('wb') as output:
            child = subprocess.Popen([str(game)], cwd=str(game.parent), env=environment,
                                     stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
            process_record['pid'] = child.pid
            manifest['processes'].append(process_record)
            write_json(run / 'launch.json', manifest)
            print(json.dumps({'run': str(run), 'phase': phase, 'pid': child.pid}, ensure_ascii=False), flush=True)
            try:
                code = child.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                # This handle is exactly the process started above, never a looked-up PID.
                child.terminate()
                code = child.wait(timeout=10)
                process_record['failure'] = 'owned test process timed out and was terminated'
            process_record['exit_code'] = code
            process_record['finished_utc'] = datetime.now(timezone.utc).isoformat()
            write_json(run / 'launch.json', manifest)
        report_path = run / 'userdata' / 'Balatro' / ('runtime-qa-result-' + phase + '.json')
        if not report_path.exists():
            raise RuntimeError('No engine result; inspect ' + str(run))
        report = json.loads(report_path.read_text(encoding='utf-8'))
        verify_report(run, report)
        if code != 0 or process_record.get('failure'):
            raise RuntimeError('Test process did not exit cleanly: ' + str(process_record))
        print(json.dumps({'status': 'passed', 'run': str(run), 'phase': phase,
                          'events': len(report.get('events', [])), 'screenshots': report['screenshots']},
                         ensure_ascii=False), flush=True)
    return run


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=Path(r'D:\SteamLibrary\steamapps\common\Balatro\Balatro.exe'))
    parser.add_argument('--smods', type=Path, default=Path(os.environ.get('APPDATA', '')) / 'Balatro/Mods/smods')
    parser.add_argument('--mod', type=Path, default=PROJECT / 'mod/TenYearsNineGrid')
    parser.add_argument('--extra-mod', type=Path, action='append', default=[],
                        help='Reviewed code/art only: DragonFantasyCity or TenYearsOneHand; never copies config.lua')
    parser.add_argument('--run-name', default=datetime.now().strftime('%Y%m%d-%H%M%S-') + uuid.uuid4().hex[:6])
    parser.add_argument('--scenario', choices=['smoke', 'cycle', 'combo', 'preset1', 'preset9', 'reload'], default='smoke')
    parser.add_argument('--seed-qa-run', help='Reload a recorded synthetic QA id; v0.4-dev:<id> or v0.5-dev:<id> permits authorized previous-version fixtures')
    parser.add_argument('--timeout', type=int, default=240)
    args = parser.parse_args()
    run_probe(args.game.resolve(), args.smods.resolve(), args.mod.resolve(), args.run_name, args.scenario,
              args.timeout, [path.resolve() for path in args.extra_mod], args.seed_qa_run)
