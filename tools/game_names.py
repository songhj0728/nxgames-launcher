#!/usr/bin/env python3
# Game names in every language the game's control data (NACP) has → <framework>/<lang>.lproj/InfoPlist.strings (CFBundleDisplayName), so the launcher and the game's
# settings screen show the name in the iPhone's language. Usage: game_names.py <framework> <control.nacp>
import pathlib, struct, sys, zlib, plistlib
LPROJ = ['en', 'en-GB', 'ja', 'fr', 'de', 'es-419', 'es', 'it', 'nl', 'fr-CA', 'pt-PT', 'ru', 'ko', 'zh-Hant', 'zh-Hans', 'pt-BR']   # the NACP's title order
fw, nacp = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
b = nacp.read_bytes(); t = b[:0x3000]
try:   # newer SDKs compress the title area (u16 size + raw deflate)
    z = zlib.decompress(b[2:2 + struct.unpack_from('<H', b)[0]], -15)
    if len(z) == 0x6000: t = z
except zlib.error: pass
names = {}
for i, lp in enumerate(LPROJ):
    n = t[i * 0x300:i * 0x300 + 0x200].split(b'\0', 1)[0].decode('utf-8', 'replace').strip()
    if n and n.isprintable(): names[lp] = n
for d in fw.glob('*.lproj'):
    (d / 'InfoPlist.strings').unlink(missing_ok=True)
    if not any(d.iterdir()): d.rmdir()
for lp, n in names.items():
    d = fw / f'{lp}.lproj'; d.mkdir(exist_ok=True)
    (d / 'InfoPlist.strings').write_bytes(plistlib.dumps({'CFBundleDisplayName': n, 'CFBundleName': n}, fmt=plistlib.FMT_BINARY))
info = fw / 'Info.plist'; p = plistlib.loads(info.read_bytes())
p['CFBundleDevelopmentRegion'] = 'en'; p['CFBundleLocalizations'] = list(names)
if 'en' in names: p['CFBundleDisplayName'] = names['en']   # the fallback for a language the game does not have
info.write_bytes(plistlib.dumps(p, fmt=plistlib.FMT_BINARY))
print(f"{fw.name}: {len(names)} languages; ko = {names.get('ko', '-')}, ja = {names.get('ja', '-')}, en = {names.get('en', '-')}")
