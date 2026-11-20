#!/usr/bin/env python3
# Check that a game framework's embedded code is that game's: every module section (__TEXT,__dm<mod>x0) must equal the start of <patched dir>/<mod>.patched.bin,
# and the rewriter tables in the bundle must equal the patched dir's. Usage: verify_fw.py <framework> <patched dir>
import pathlib, re, subprocess, sys, filecmp
fw, pd = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
exe = fw / 'DmIOS'
out = subprocess.run(['otool', '-l', str(exe)], capture_output=True, text=True, check=True).stdout
secs = {}
for blk in out.split('Section\n')[1:]:
    f = dict(re.findall(r'^\s*(\w+) (\S+)$', blk, re.M))
    if f.get('segname') == '__TEXT' and re.fullmatch(r'__dm\w+x0', f.get('sectname', '')): secs[f['sectname'][4:-2]] = (int(f['offset']), int(f['size'], 16))
bad = []
mods = sorted(p.name[:-len('.patched.bin')] for p in pd.glob('*.patched.bin'))
with open(exe, 'rb') as e:
    for m in mods:
        if m not in secs: bad.append(f'{m}: no embedded section'); continue
        off, size = secs[m]; e.seek(off); a = e.read(size)
        with open(pd / f'{m}.patched.bin', 'rb') as f: b = f.read(size)
        if a != b: bad.append(f'{m}: embedded code differs from {pd}')
for t in pd.glob('*.fixups.tsv'):
    if not (fw / "dm" / t.name).exists() or not filecmp.cmp(t, fw / "dm" / t.name, shallow=False): bad.append(f"{t.name} differs or is missing")
print(f'{fw.name}: {"OK" if not bad else "MISMATCH"} ({len(mods)} modules checked against {pd})')
for b in bad: print('  ' + b)
sys.exit(1 if bad else 0)
