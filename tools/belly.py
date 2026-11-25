#!/usr/bin/env python3
# belly.py LOG...: from logs made with --who, per log: member-hours with an empty belly (a who: line at 0 % fed with the
# place printed, which the runner adds for whoever is starving), how many of them are worded "starving", hours in which
# the least-fed of the band is at nothing (the food line), who is left, deaths.  -s: one summed line for all the logs.
import sys, re, os, collections
args=sys.argv[1:]
summed = '-s' in args
args=[a for a in args if a!='-s']
T=collections.Counter()
for f in args:
    empty=worded=zero_hours=hours=deaths=0; living=None; who=collections.Counter(); cant=0
    for l in open(f, errors='replace'):
        m=re.match(r'food: day (\d+) ([\d.]+) h:\s+(\d+) living, confidence (\d+) %, fed (\d+)/(\d+) %', l)
        if m:
            hours+=1; living=int(m.group(3)); zero_hours+= int(m.group(5))==0
            continue
        w=re.match(r'\s+who: (\w+),\s+(-?\d+) % fed: (.*)$', l)
        if w:
            at = re.search(r'\(at [-0-9.]+ [-0-9.]+ [-0-9.]+\)\s*$', w.group(3)) is not None
            if at and int(w.group(2))<=0:
                empty+=1; who[w.group(1)]+=1
                worded+= w.group(3).startswith('starving')
            elif at:
                cant+=1
            continue
        if 'has died of hunger' in l: deaths+=1
    T['logs']+=1; T['empty']+=empty; T['worded']+=worded; T['zero_hours']+=zero_hours; T['deaths']+=deaths; T['with']+= empty>0; T['cant']+=cant
    T['not13']+= living!=13
    if not summed:
        print('%-34s empty-belly member-hours %4d (worded starving %3d); hours the least fed is at nothing %4d of %5d; cannot get there %d; living %s; deaths %d%s' % (os.path.basename(f)[:-4][:34], empty, worded, zero_hours, hours, cant, living, deaths, ('; ' + ', '.join('%s %d' % kv for kv in who.most_common(4))) if who else ''))
if summed:
    print('%d logs: empty-belly member-hours %d (worded starving %d) in %d of them; hours the least fed is at nothing %d; cannot get there %d; deaths %d; logs not ending with 13 living %d' % (T['logs'], T['empty'], T['worded'], T['with'], T['zero_hours'], T['cant'], T['deaths'], T['not13']))
