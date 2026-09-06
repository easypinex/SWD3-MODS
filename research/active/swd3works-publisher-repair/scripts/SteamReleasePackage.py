"""Read SMOD v4 manifest/version; prepare an isolated single-package release.

Only reads the first Zstandard manifest, not a general resource unpacker.
Python 3 + zstandard 0.25.0. No Steam calls or game-directory writes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import uuid
import zstandard


def inspect(path):
    path = Path(path).resolve(strict=True)
    with path.open('rb') as stream:
        head = stream.read(1048576)
        if head[:4] != b'SMOD' or struct.unpack_from('<I', head, 4)[0] != 4:
            raise ValueError('Only SMOD v4 packages are supported')
        offset = head.find(bytes.fromhex('28b52ffd'))
        if offset < 8:
            raise ValueError('Manifest frame not found')
        frame_size = zstandard.frame_content_size(head[offset:])
        if frame_size < 0 or frame_size > 16777216:
            raise ValueError('Manifest must declare a size of at most 16 MB')
    with path.open('rb') as stream:
        stream.seek(offset)
        decoder = zstandard.ZstdDecompressor().decompressobj()
        parts, count = [], 0
        while not decoder.eof:
            chunk = stream.read(4096)
            if not chunk:
                raise ValueError('Incomplete manifest frame')
            block = decoder.decompress(chunk)
            count += len(block)
            if count > 16777216:
                raise ValueError('Manifest exceeds 16 MB')
            parts.append(block)
    manifest = b''.join(parts).decode('utf-8-sig')
    versions = re.findall(r'^MODVersion[ \t]+(\d+)[ \t]*,[ \t]*(\d+)[ \t]*\r?$', manifest, re.M)
    names = re.findall(r'^MODName[ \t]+(.+)\r?$', manifest, re.M)
    if len(versions) != 1 or len(names) != 1:
        raise ValueError('Expected one MODName and one two-part MODVersion')
    major, minor = map(int, versions[0])
    if max(major, minor) > 2147483647:
        raise ValueError('Version component exceeds supported range')
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            digest.update(chunk)
    return dict(Version=f'{major}.{minor}', Name=names[0].strip(), FileName=path.name,
                Size=path.stat().st_size, Sha256=digest.hexdigest().upper(),
                ManifestSha256=hashlib.sha256(b''.join(parts)).hexdigest().upper())


def prepare(draft_path, output):
    draft = json.loads(Path(draft_path).read_text(encoding='utf-8-sig'))
    package = Path(draft['Package']).resolve(strict=True)
    if package.suffix.lower() != '.ssmod':
        raise ValueError('Package must be .ssmod')
    info = inspect(package)
    if 'Version' in draft and draft['Version'] != info['Version']:
        raise ValueError('Draft version differs from packaged MODVersion')
    output = Path(output).resolve()
    # Outputs must live in this workspace; game paths cannot be destinations.
    workspace = Path(__file__).resolve().parents[4]
    if not output.is_relative_to(workspace) or output == workspace:
        raise ValueError('Output must be a new directory inside this workspace')
    output.mkdir(parents=True, exist_ok=False)
    (output / 'content').mkdir()
    target = output / 'content' / package.name
    shutil.copyfile(package, target)
    if inspect(target) != info:
        raise ValueError('Package changed during snapshot')
    preview = None
    preview_hash = None
    if draft.get('PreviewFile'):
        source = Path(draft['PreviewFile']).resolve(strict=True)
        preview = output / ('preview' + source.suffix.lower())
        shutil.copyfile(source, preview)
        preview_hash = hashlib.sha256(preview.read_bytes()).hexdigest().upper()
    plan = dict(Schema=3, AppId=1638230, OperationId=uuid.uuid4().hex,
                WorkshopId=draft.get('WorkshopId'), Version=info['Version'],
                ContentDirectory=str(output / 'content'), FileName=info['FileName'],
                ContentSha256=info['Sha256'], ContentSize=info['Size'],
                Title=draft['Title'], Description=draft['Description'],
                Language=draft.get('Language', 'tchinese'),
                Visibility=draft.get('Visibility', 'preserve' if draft.get('WorkshopId') else 'private'),
                ChangeNote=draft['ChangeNote'], PreviewFile=str(preview) if preview else None,
                PreviewSha256=preview_hash)
    (output / 'plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding='utf-8')
    (output / 'package.json').write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(dict(plan=str(output / 'plan.json'), package=info), ensure_ascii=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    cmd = sub.add_parser('inspect')
    cmd.add_argument('package')
    cmd = sub.add_parser('prepare')
    cmd.add_argument('draft')
    cmd.add_argument('output')
    args = parser.parse_args()
    if args.command == 'inspect':
        print(json.dumps(inspect(args.package), ensure_ascii=True))
    else:
        prepare(args.draft, args.output)
