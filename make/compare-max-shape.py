#!/usr/bin/env python3
"""Show the value-association shape of branchy scalar max reductions in HotSpot assembly."""
import argparse, re, sys
from pathlib import Path

INSN = re.compile(r'^\s*(?:0x[0-9a-f]+):\s+([a-z][a-z0-9]*)\s*(.*?)\s*(?:;.*)?$', re.I)
REG = re.compile(r'%[a-z]+[0-9]*', re.I)
MEM_OFF = re.compile(r'(?:(0x[0-9a-f]+)|(-?\d+))?\(%[^)]*\)')

def parse(path):
    rows=[]
    for n,line in enumerate(Path(path).read_text(errors='replace').splitlines(),1):
        m=INSN.match(line)
        if m: rows.append((n,m.group(1).lower(),m.group(2).strip(),line))
    return rows

def operand_regs(s): return REG.findall(s)

def mem_name(op):
    m=MEM_OFF.search(op)
    if not m: return 'MEM[?]'
    raw=m.group(1) or m.group(2) or '0'
    try: value=int(raw,0)
    except ValueError: return f'MEM[{raw}]'
    return f'MEM[{value:+#x}]'

def analyze(path):
    rows=parse(path)
    # Restrict to the first printed inner loop if markers are available.
    state={}
    loaded=set()
    comparisons=[]
    zero_regs=set()
    for line_no,op,args,raw in rows:
        regs=operand_regs(args)
        if op == 'vmovsd' and '(' in args and regs:
            dst=regs[-1]; state[dst]=mem_name(args); loaded.add(dst)
        elif op in ('vmovapd','vmovsd') and len(regs)>=2 and '(' not in args:
            src,dst=regs[0],regs[-1]; state[dst]=state.get(src,src)
        elif op in ('vpxor','vxorpd','vxorps') and len(regs)>=3 and regs[0]==regs[1]==regs[2]:
            state[regs[-1]]='0.0'; zero_regs.add(regs[-1])
        elif op == 'vucomisd' and len(regs)>=2:
            src,dst=regs[0],regs[1]  # AT&T: flags from dst - src
            sv=state.get(src, 'ACC' if src not in loaded else src)
            dv=state.get(dst, 'ACC' if dst not in loaded else dst)
            # Exclude signed-zero helper compares.
            if sv == '0.0':
                continue
            comparisons.append({
                'line':line_no,'src_reg':src,'dst_reg':dst,
                'src':sv,'dst':dv,'expr':f'max({dv}, {sv})'
            })
            state[dst]=f'max({dv}, {sv})'
    return comparisons

def compact(expr, limit=100):
    return expr if len(expr)<=limit else expr[:limit-3]+'...'

def report(path):
    comps=analyze(path)
    print(f'FILE: {path}')
    print(f'Primary max comparisons: {len(comps)}')
    for i,c in enumerate(comps,1):
        acc = '  <== loop-carried value involved' if 'ACC' in (c['src'],c['dst']) else ''
        print(f'{i:2d}. line {c["line"]:4d}: {c["dst_reg"]}({compact(c["dst"],55)})  vs  '
              f'{c["src_reg"]}({compact(c["src"],55)}){acc}')
    if comps:
        first_acc=next((i for i,c in enumerate(comps,1) if 'ACC' in (c['src'],c['dst'])),None)
        print(f'Loop-carried accumulator first participates at comparison: {first_acc or "not detected"}')
        print(f'Final inferred expression: {compact(comps[-1]["expr"],220)}')
    return comps

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('logs',nargs='+',help='one or more PrintAssembly logs')
    ns=ap.parse_args()
    results=[]
    for i,p in enumerate(ns.logs):
        if i: print('\n'+'='*80+'\n')
        results.append(report(p))
    if len(results)==2:
        a,b=results
        def first_acc(cs): return next((i for i,c in enumerate(cs,1) if 'ACC' in (c['src'],c['dst'])),None)
        print('\n'+'='*80)
        print('COMPARISON SUMMARY')
        print(f'FIRST : {ns.logs[0]}')
        print(f'SECOND: {ns.logs[1]}')
        print(f'Accumulator entry point: FIRST={first_acc(a)}, SECOND={first_acc(b)}')
        if first_acc(a) != first_acc(b):
            print('DIFFERENCE: the reduction is associated differently even if opcode counts match.')

if __name__=='__main__': main()
