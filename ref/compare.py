#!/usr/bin/env python3
"""Compara decisiones.csv (salida del testbench) con la referencia Python, tick a tick."""
import sys, os, csv
sys.path.insert(0, os.path.dirname(__file__))
import market, trader_ref, trader_ref_ema
serie, dec_csv = sys.argv[1], sys.argv[2]
mod = trader_ref_ema if len(sys.argv) > 3 and sys.argv[3] == 'ema' else trader_ref
rows = list(csv.reader(open(dec_csv)))[1:]
hw = [int(r[2], 16) for r in rows]
pr = market.load_csv(serie)[:len(hw)]
ref = mod.decisions(pr)
bad = [i for i in range(len(hw)) if hw[i] != ref[i]]
print(f"{len(hw)} ticks, diferencias: {len(bad)}", bad[:5])
sys.exit(1 if bad else 0)
