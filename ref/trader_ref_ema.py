#!/usr/bin/env python3
"""Referencia bit-exacta de trade_shift.s (variante HW-2, con shifter): cruce de EMA rapida (alfa=2^-6)
y lenta (alfa=2^-8), SF = 64*ema_f, SS = 256*ema_s; d = 4*SF - SS = 256*(ema_f - ema_s); banda 1.5."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import market
THR, BURST, BUY63, SELL63, HOLD = 384, 6, 0x7F, 0xBF, 0x00
class Trader:
    def __init__(self):
        self.first = True; self.sf = self.ss = 0; self.long = 1; self.burst = BURST
    def step(self, p):
        if self.first: self.sf = p << 6; self.ss = p << 8; self.first = False
        self.sf += p - (self.sf >> 6); self.ss += p - (self.ss >> 8)
        d = 4*self.sf - self.ss; new = self.long
        if d > THR: new = 1
        elif d < -THR: new = 0
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
