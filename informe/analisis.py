#!/usr/bin/env python3
"""Genera tablas (informe/datos.json) y figuras (informe/fig/*.pdf) para el informe.
Requiere: python3 + numpy + matplotlib; haber corrido los testbenches (perfil en /tmp/p4r/prof o ruta dada)."""
import sys, os, json, csv
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ref'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'sw'))
import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
import market, trader_ref, trader_ref_ema, assembler
ROOT = os.path.join(os.path.dirname(__file__), '..'); PROF = sys.argv[1] if len(sys.argv) > 1 else '/tmp/p4r/prof'
pr = market.load_csv(os.path.join(ROOT, 'tb/practica.csv'))
def curves(prices, decs):
    caja, acc, W, orders = 10000, 0, [], 0
    for p, d in zip(prices, decs):
        a, q = d >> 6, d & 63
        if a == 1:
            q = min(q, (caja-5)//p) if caja >= 5 else 0
            if q > 0: caja -= q*p+5; acc += q; orders += 1
        elif a == 2:
            q = min(q, acc)
            if q > 0: caja += q*p-5; acc -= q; orders += 1
        W.append(caja+acc*p)
    return np.array(W), orders
res = {}
for name, dec in [('V0 SMA128/512', trader_ref.decisions(pr)), ('V2 EMA 64/256', trader_ref_ema.decisions(pr))]:
    W, o = curves(pr, dec); pk = np.maximum.accumulate(np.maximum(W, 10000))
    res[name] = dict(final=int(W[-1]), ordenes=o, comisiones=5*o, max_dd=int((pk-W).max()), W=W)
q = (10000-5)//pr[0]; bhW = np.array([10000-5-q*pr[0]+q*p for p in pr]); pk = np.maximum.accumulate(np.maximum(bhW, 10000))
res['Comprar y mantener'] = dict(final=int(bhW[-1]), ordenes=1, comisiones=5, max_dd=int((pk-bhW).max()), W=bhW)
res['No operar'] = dict(final=10000, ordenes=0, comisiones=0, max_dd=0, W=np.full(len(pr), 10000))
tabla = {k: {kk: vv for kk, vv in v.items() if kk != 'W'} for k, v in res.items()}
# figura 1: precio y patrimonio
fig, ax = plt.subplots(2, 1, figsize=(7, 5), sharex=True)
ax[0].plot(pr, lw=.6, color='k'); ax[0].set_ylabel('precio normalizado')
for k, c in [('No operar', 'gray'), ('Comprar y mantener', 'tab:blue'), ('V0 SMA128/512', 'tab:orange'), ('V2 EMA 64/256', 'tab:green')]:
    ax[1].plot(res[k]['W'], lw=.8, label=k, color=c)
ax[1].set_ylabel('patrimonio ($)'); ax[1].set_xlabel('tick'); ax[1].legend(fontsize=7); plt.tight_layout(); plt.savefig(os.path.join(ROOT, 'informe/fig/patrimonio.pdf')); plt.close()
# perfil por region (Amdahl)
def regions(src, hexcsv):
    text = open(os.path.join(ROOT, 'sw', src)).read()
    ins, labels = assembler.parse_source(text)
    lab = sorted(labels.items(), key=lambda kv: kv[1])
    prof = {int(r['pc']): (int(r['ciclos']), int(r['ic'])) for r in csv.DictReader(open(hexcsv))}
    out = {}
    for pc, (c, i) in prof.items():
        name = [n for n, a in lab if a <= pc][-1] if any(a <= pc for n, a in lab) else '_start'
        o = out.setdefault(name, [0, 0]); o[0] += c; o[1] += i
    tot = sum(v[0] for v in out.values())
    return {k: dict(ciclos=v[0], ic=v[1], pct=round(100*v[0]/tot, 1)) for k, v in out.items()}, tot
prof = {}
for v, src in [('SW', 'trade_sw.s'), ('SMA', 'trade_hw.s'), ('FIN', 'trade.s')]:
    prof[v], _ = regions(src, os.path.join(PROF, v+'.csv'))
# histograma de ciclos por tick
fig, ax = plt.subplots(figsize=(6, 3))
for v, lab in [('SW', 'V0'), ('SMA', 'V1'), ('FIN', 'V2')]:
    c = [int(r['ciclos']) for r in csv.DictReader(open(os.path.join(PROF, v+'_metricas.csv')))][1:]
    ax.hist(c, bins=range(40, 110), alpha=.6, label=lab)
ax.set_xlabel('ciclos precio$\\to$decisión'); ax.set_ylabel('ticks'); ax.legend(); plt.tight_layout(); plt.savefig(os.path.join(ROOT, 'informe/fig/ciclos_tick.pdf')); plt.close()
json.dump(dict(tabla=tabla, perfil=prof), open(os.path.join(ROOT, 'informe/datos.json'), 'w'), indent=1, ensure_ascii=False)
print(json.dumps(tabla, indent=1)); print(json.dumps(prof, indent=1))
