"""Check local Markdown file links and heading anchors without modifying files."""
from pathlib import Path
from collections import Counter
from urllib.parse import unquote
import argparse
import os
import re
import unicodedata

SKIP = {'.git', '.tools', '.work', 'Mods', 'Save', 'SnapShot', 'archive',
        'node_modules', '__pycache__', 'native-analysis', 'dist', 'build',
        'out_data', 'out_data_1', 'out_data_2', 'out_data_3', 'hd_tsw_png', 'tsw', 'tsw_png'}
LINK = re.compile(r'!?\[[^\]\n]*\]\((<[^>\n]+>|[^)\n]+)\)')

def strip_fences(text):
    lines=[]; fence=None
    for line in text.splitlines():
        m=re.match(r'^\s*(`{3,}|~{3,})',line)
        if m:
            token=m[1]
            if fence is None: fence=token
            elif token[0]==fence[0] and len(token)>=len(fence): fence=None
            lines.append(''); continue
        lines.append('' if fence else line)
    return '\n'.join(lines)

def slug(text):
    text=re.sub(r'<[^>]+>','',text).strip().lower()
    text=re.sub(r'\[([^]]+)\]\([^)]+\)',r'\1',text)
    return ''.join(c for c in text if c in '-_ ' or unicodedata.category(c)[0] in 'LMN').replace(' ','-')

def headings(path):
    text=strip_fences(path.read_text(encoding='utf-8-sig'))
    ids=set(re.findall(r'<a\s+(?:id|name)=["\']([^"\']+)',text))
    seen=Counter()
    for title in re.findall(r'^#{1,6}\s+(.+?)(?:\s+#+)?$',text,re.M):
        base=slug(title); n=seen[base]; seen[base]+=1
        ids.add(base+('-'+str(n) if n else ''))
    return ids

def documents(root):
    for base,dirs,files in os.walk(root):
        # research/archive is curated evidence; root archive holds local safety backups.
        dirs[:]=[d for d in dirs if (d not in SKIP or (d=='archive' and Path(base).name=='research'))
                 and not d.startswith(('_build','_verify','verify-','_critical','_guardian','_retired'))]
        for name in files:
            if name.lower().endswith('.md'): yield Path(base)/name

def check(root):
    errors=[]; files=list(documents(root)); count=0; anchors={}
    for file in files:
        text=strip_fences(file.read_text(encoding='utf-8-sig'))
        for m in LINK.finditer(text):
            target=m[1]
            if target.startswith('<'): target=target[1:-1]
            else: target=re.split(r'\s+["\']',target,maxsplit=1)[0]
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:',target) or target.startswith('//'): continue
            if '<' in target or '>' in target: continue  # documented placeholders
            count+=1
            path,sep,anchor=target.partition('#')
            dst=(file.parent/unquote(path)).resolve() if path else file
            line=text.count('\n',0,m.start())+1
            reason=None
            if not dst.exists(): reason='missing file'
            elif anchor and dst.suffix.lower()=='.md':
                if dst not in anchors: anchors[dst]=headings(dst)
                if unquote(anchor) not in anchors[dst]: reason='missing anchor'
            elif anchor and re.fullmatch(r'L\d+(?:-L?\d+)?',anchor) and dst.is_file():
                line_no=int(re.search(r'\d+',anchor)[0])
                if len(dst.read_text(encoding='utf-8-sig').splitlines())<line_no: reason='missing source line'
            if reason: errors.append(f'{file.relative_to(root).as_posix()}:{line}: {reason}: {target}')
    return files,count,errors

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    args=parser.parse_args()
    files,count,errors=check(args.root.resolve())
    for e in errors: print(e)
    print(f'{"FAIL" if errors else "PASS"}: {len(files)} Markdown files, {count} local links, {len(errors)} errors')
    raise SystemExit(bool(errors))
