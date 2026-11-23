#!/usr/bin/env python3
"""Summarize raw probe output (bpftrace map dump, or the identical format written by the gdb stand-in).

usage: probe-report.py <raw-output> [perf-map]

Input lines:
  @alloc[<context>, <class>]: <count>
  @c2_site[<class>, <return pc>]: <count>
  cpid=<pid>
The perf map (/tmp/perf-<pid>.map, written by -XX:+DumpPerfMapAtExit) resolves C2 return pcs to the
compiled method (compilation unit) that contains the allocation.
"""
import re, sys, collections

raw = open(sys.argv[1]).read().splitlines()
alloc = collections.Counter(); sites = collections.Counter()
for l in raw:
    m = re.match(r'@alloc\[(.*), (.*)\]: (\d+)$', l)
    if m: alloc[(m.group(1).strip(), m.group(2).strip())] += int(m.group(3)); continue
    m = re.match(r'@c2_site\[(.*), (\d+)\]: (\d+)$', l)
    if m: sites[(m.group(1).strip(), int(m.group(2)))] += int(m.group(3))

pmap = []
if len(sys.argv) > 2:
    for l in open(sys.argv[2]):
        a, s, n = l.rstrip('\n').split(' ', 2)
        pmap.append((int(a, 16), int(s, 16), n))
def resolve(pc):
    for a, s, n in pmap:
        if a <= pc < a + s: return n
    return '0x%x (unresolved)' % pc

by_ctx = collections.Counter()
for (c, k), n in alloc.items(): by_ctx[c] += n
total = sum(by_ctx.values())
print("Instance allocations by HotSpot entry point (exact counts)")
for c, n in by_ctx.most_common():
    print("  %-48s %12d  %5.1f%%" % (c, n, 100.0 * n / total))
print("\nTop (entry point, class)")
for (c, k), n in alloc.most_common(12):
    print("  %-48s %-36s %12d" % (c, k.replace('/', '.'), n))
if sites:
    print("\nC2 allocation sites (OptoRuntime::new_instance_C) resolved to compiled methods")
    agg = collections.Counter()
    for (k, pc), n in sites.items(): agg[(k, resolve(pc))] += n
    for (k, meth), n in agg.most_common(10):
        print("  %-24s %12d  in  %s" % (k.replace('/', '.'), n, meth))
