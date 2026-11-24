#!/usr/bin/env python3
"""Referencia bit-exacta de trade.s (variante final con shifter parcial).

Usa EMA rapida (alfa=2^-6) y lenta (alfa=2^-8):
SF = 64*ema_f, SS = 256*ema_s y d = 4*SF - SS.
Sin movimientos bruscos, la histeresis exige una ventaja mayor que 5 para
comprar y una desventaja menor que -8 para vender. Un cambio de mas de 10
unidades en un tick tiene prioridad y fija su direccion durante 1600 ticks.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import market
BUY_THR, SELL_THR = 1280, 2048
JUMP_THR, JUMP_LOCK = 10, 1600
BUY63, SELL63 = 0x7F, 0xBF
class Trader:
    def __init__(self):
        self.first = True; self.sf = self.ss = self.prev = 0
        self.long = 1; self.lock = 0
    def step(self, p):
        if self.first:
            self.sf = p << 6; self.ss = p << 8; self.prev = p; self.first = False
        dp = p - self.prev; self.prev = p
        self.sf += p - (self.sf >> 6); self.ss += p - (self.ss >> 8)
        d = 4*self.sf - self.ss; new = self.long
        if dp > JUMP_THR: new = 1; self.lock = JUMP_LOCK
        elif dp < -JUMP_THR: new = 0; self.lock = JUMP_LOCK
        elif self.lock: self.lock -= 1
        elif d > BUY_THR: new = 1
        elif d < -SELL_THR: new = 0
        self.long = new
        # Una orden puede mover como maximo 63 acciones. Se repite mientras
        # dure el estado; la maestra ignora sin comision la parte no ejecutable.
        return BUY63 if self.long else SELL63
def decisions(prices):
    t = Trader(); out, d = [], 0
    for p in prices: out.append(d); d = t.step(p)
    return out
if __name__ == '__main__':
    pr = market.load_csv(sys.argv[1]); r = market.run(pr, decisions(pr))
    print(f"patrimonio {r['w']}  ordenes {r['orders']}  max_dd {r['mdd']}  B&H {market.buy_hold(pr)}")
