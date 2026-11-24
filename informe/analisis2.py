#!/usr/bin/env python3
"""Perfil por instruccion, ops/bytes y figura roofline.
Uso: python3 informe/analisis2.py [dir_perfiles]"""
import sys, os, csv, json, re
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, R+'/ref'); sys.path.insert(0, R+'/sw'); sys.path.insert(0, '/tmp/p4r')
import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
import assembler, market, trader_ref, trader_ref_ema
PROF = sys.argv[1] if len(sys.argv) > 1 else '/tmp/p4r/prof'
ALU = {'add','addi','sub','and','andi','or','ori','xor','xori','slt','slti','sltu','sltiu','sll','slli','srl','srli','sra','srai','lui'}
MEM = {'lw':4,'sw':4,'lbu':1,'sb':1}
out = {}
for v, src, name in [('SW','trade_sw.s','V0'), ('SMA','trade_hw.s','V1'), ('FIN','trade.s','V2')]:
    ins, labels = assembler.parse_source(open(f'{R}/sw/{src}').read())
    addr2 = {i.address: i for i in ins}
    lab = sorted(labels.items(), key=lambda kv: kv[1])
    prof = {int(r['pc']): (int(r['ciclos']), int(r['ic'])) for r in csv.DictReader(open(f'{PROF}/{v}.csv'))}
    N = 1999   # ticks medidos con perfil (se descarta el primero)
    rows = []; ops = 0; byt = 0; cyc = 0; ic = 0; wait_c = 0
    for pc in sorted(prof):
        c, i = prof[pc]; text = addr2[pc].text if pc in addr2 else '?'
        mn = text.split()[0].lower(); region = [n for n, a in lab if a <= pc][-1]
        rows.append((pc, region, text, c/N, i/N))
        cyc += c; ic += i
        poll = region in ('wait_price','wait_acc') and (re.search(r'x11, 0\(x(1|14)\)', text) or text.startswith('andi x11, x11, 1') or re.match(r'b(eq|ne) x11, x0, wait_', text))
        if poll: wait_c += c; continue      # sondeo del aviso: espera, no es computo
        if mn in ALU: ops += i
        if mn in MEM: byt += MEM[mn]*i
    if name == 'V1': ops += 4*N            # 4 pasos del sumador del acelerador (S2..S5)
    out[name] = dict(ops_tick=ops/N, bytes_tick=byt/N, ciclos_tick=cyc/N, ic_tick=ic/N, ciclos_espera=wait_c/N)
    with open(f'{R}/informe/perfil_{name}.csv', 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['pc','region','instruccion','ciclos_por_tick','ic_por_tick']); [w.writerow([a,b,c,round(d,3),round(e,3)]) for a,b,c,d,e in rows]
# fraccion acelerable en V0: desde 'update' hasta el calculo de d (inclusive)
ins, labels = assembler.parse_source(open(f'{R}/sw/trade_sw.s').read())
prof = {int(r['pc']): int(r['ciclos']) for r in csv.DictReader(open(f'{PROF}/SW.csv'))}
a0 = labels['update']; sub_d = [i.address for i in ins if i.text.replace(',',' ').split()[:2] == ['sub','x11'] and 'x6' in i.text][-1]
tot = sum(prof.values()); acc = sum(c for pc, c in prof.items() if a0 <= pc <= sub_d)
out['amdahl'] = dict(f_update=acc/tot, cota=1/(1-acc/tot))
# roofline
F = 25e6; peak = F*1.0; bw = F*2.0       # 1 op/ciclo (CPI=1); un lw tarda 2 ciclos -> 2 B/ciclo
fig, ax = plt.subplots(figsize=(5.5, 3.6)); I = np.logspace(-2, 1.5, 100)
ax.loglog(I, np.minimum(peak, bw*I)/1e6, 'k', lw=1.5, label='techo del Espino')
for k, c in [('V0','tab:orange'), ('V1','tab:purple'), ('V2','tab:green')]:
    o = out[k]; intens = o['ops_tick']/max(o['bytes_tick'],1e-9); perf = o['ops_tick']/((o['ciclos_tick']-o['ciclos_espera'])/F)
    out[k].update(intensidad=intens, perf_mops=perf/1e6); ax.loglog([intens],[perf/1e6],'o',color=c,label=k)
ax.set_xlabel('intensidad operacional (ops/byte)'); ax.set_ylabel('Mops/s'); ax.legend(fontsize=8); ax.grid(True, which='both', alpha=.3)
plt.tight_layout(); plt.savefig(R+'/informe/fig/roofline.pdf'); plt.close()
json.dump(out, open(R+'/informe/datos2.json', 'w'), indent=1)
print(json.dumps(out, indent=1))
