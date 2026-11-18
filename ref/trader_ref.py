#!/usr/bin/env python3
"""Referencia bit-exacta de trade.s: cruce de SMA(N1)/SMA(N2) con histeresis, solo aritmetica
entera sin multiplicaciones ni shifts (N2 = 4*N1, por lo que 4*S1 - S2 = 512*(SMA1-SMA2)).
Uso: python3 ref/trader_ref.py tb/practica.csv"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import market

N1, N2, THR, BURST = 128, 512, 512, 6   # THR = banda de 1.0 unidad de precio (x512)
BUY63, SELL63, HOLD = 0x7F, 0xBF, 0x00

class Trader:
    def __init__(self, start_long=True):
        self.n = 0; self.buf = [0]*N2; self.i = 0
        self.p0 = self.s1 = self.s2 = 0
        self.long = 1 if start_long else 0
        self.burst = BURST if start_long else 0
    def step(self, p):
        """Recibe p_n, devuelve el byte DECISION que se escribira (se ejecutara en p_{n+1})."""
        if self.n == 0:
            self.p0 = p; self.s1 = N1*p; self.s2 = N2*p
        old2 = self.buf[self.i] if self.n >= N2 else self.p0
        old1 = self.buf[(self.i - N1) % N2] if self.n >= N1 else self.p0
        self.buf[self.i] = p
        self.s1 += p - old1; self.s2 += p - old2
        self.i = (self.i + 1) % N2
        if self.n < N2: self.n += 1
        d = 4*self.s1 - self.s2
        new = self.long
        if d > THR: new = 1
        elif d < -THR: new = 0
        if new != self.long: self.burst = BURST
        self.long = new
        if self.burst:
            self.burst -= 1
            return BUY63 if self.long else SELL63
        return HOLD

def decisions(prices, **kw):
    t = Trader(**kw); out, d = [], 0
    for p in prices:
        out.append(d); d = t.step(p)      # la maestra ejecuta d_{n-1} al precio p_n
    return out

if __name__ == '__main__':
    pr = market.load_csv(sys.argv[1]); n = int(sys.argv[2]) if len(sys.argv) > 2 else len(pr)
    pr = pr[:n]; r = market.run(pr, decisions(pr))
    print(f"patrimonio {r['w']}  ordenes {r['orders']}  max_dd {r['mdd']}  B&H {market.buy_hold(pr)}")
