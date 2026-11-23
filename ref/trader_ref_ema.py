#!/usr/bin/env python3
"""Referencia bit-exacta de trade.s (variante final con shifter parcial).

Usa EMA rapida (alfa=2^-6) y lenta (alfa=2^-8):
SF = 64*ema_f, SS = 256*ema_s y d = 4*SF - SS.
La histeresis asimetrica exige una ventaja mayor que 3 para comprar y una
desventaja menor que -5 para vender, reduciendo cambios por ruido.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import market
BUY_THR, SELL_THR = 768, 1280
BURST, BUY63, SELL63, HOLD = 6, 0x7F, 0xBF, 0x00
class Trader:
    def __init__(self):
        self.first = True; self.sf = self.ss = 0; self.long = 1; self.burst = BURST
    def step(self, p):
        if self.first: self.sf = p << 6; self.ss = p << 8; self.first = False
        self.sf += p - (self.sf >> 6); self.ss += p - (self.ss >> 8)
        d = 4*self.sf - self.ss; new = self.long
        if d > BUY_THR: new = 1
        elif d < -SELL_THR: new = 0
        if new != self.long: self.burst = BURST
        self.long = new
        if self.burst: self.burst -= 1; return BUY63 if self.long else SELL63
        return HOLD
def decisions(prices):
    t = Trader(); out, d = [], 0
    for p in prices: out.append(d); d = t.step(p)
    return out
if __name__ == '__main__':
    pr = market.load_csv(sys.argv[1]); r = market.run(pr, decisions(pr))
    print(f"patrimonio {r['w']}  ordenes {r['orders']}  max_dd {r['mdd']}  B&H {market.buy_hold(pr)}")
