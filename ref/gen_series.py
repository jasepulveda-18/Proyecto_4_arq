"""Genera series sinteticas de 20000 ticks (1 min) a partir de OHLC diario real 2022-24
(Yahoo, ver README) con gaps nocturnos reales y puente browniano intradia. Solo para
validar robustez; NO se usa nada de esto dentro del diseno final."""
import json, sys, numpy as np
def daily(t):
    d = json.load(open(f'/tmp/p4data/{t}.json'))['chart']['result'][0]; q = d['indicators']['quote'][0]
    return [(o,h,l,c) for o,h,l,c in zip(q['open'],q['high'],q['low'],q['close']) if None not in (o,h,l,c)]
def make(days, rng, nmin=390):
    px = []
    for i,(o,h,l,c) in enumerate(days):
        t = np.arange(nmin)/ (nmin-1)
        base = o + (c-o)*t
        w = np.cumsum(rng.standard_normal(nmin)); w = w - w[0] - t*(w[-1]-w[0])   # puente
        amp = (h-l)*0.55
        w = w/ (np.abs(w).max()+1e-9) * amp * rng.uniform(.5,1.0)
        px.append(base + w)
    return np.concatenate(px)
def norm(x):
    x = (x - x.min())/(x.max()-x.min())
    return np.round(100 + 155*x).astype(int)
def all_series(seed=1, per_ticker=12, ndays=52):
    rng = np.random.default_rng(seed); out = []
    for t in ['META','AAPL','NFLX','AMD','TSLA']:
        D = daily(t)
        for k in range(per_ticker):
            s = int(rng.integers(0, len(D)-ndays)); off = int(rng.integers(0,390))
            x = make(D[s:s+ndays], rng)[off:off+20000]
            out.append((f'{t}_{s}', norm(x).tolist()))
    return out
if __name__ == '__main__':
    S = all_series()
    print(len(S), [len(x[1]) for x in S][:3])
