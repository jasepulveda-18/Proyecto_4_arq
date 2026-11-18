"""Contabilidad oficial (identica a tb_proyecto_4.sv) y utilidades de series."""
import csv
CAJA0, COM = 10000, 5

def load_csv(path):
    with open(path) as f:
        r = csv.reader(f); next(r)
        return [int(x[1]) for x in r]

def run(prices, decisions):
    """decisions[n] = byte devuelto en la transaccion n (calculado con precios hasta n-1).
    Devuelve dict con patrimonio final, ordenes, max drawdown."""
    caja, acc, peak, mdd, orders = CAJA0, 0, CAJA0, 0, 0
    for p, d in zip(prices, decisions):
        a, q = d >> 6, d & 63
        if a == 1:
            q = min(q, (caja - COM) // p) if caja >= COM else 0
            if q > 0: caja -= q*p + COM; acc += q; orders += 1
        elif a == 2:
            q = min(q, acc)
            if q > 0 and caja + q*p >= COM: caja += q*p - COM; acc -= q; orders += 1
        w = caja + acc*p
        peak = max(peak, w); mdd = max(mdd, peak - w)
    return dict(w=w, orders=orders, mdd=mdd, caja=caja, acc=acc)

def buy_hold(prices):
    q = (CAJA0 - COM)//prices[0]
    return CAJA0 - COM - q*prices[0] + q*prices[-1]

def simulate(prices, agent):
    """agent(p)->byte; se llama con p_n y su resultado se ejecuta en p_{n+1} (retardo de 1 tick)."""
    dec, d = [], 0
    for p in prices:
        dec.append(d)
        d = agent(p)
    return run(prices, dec), dec
