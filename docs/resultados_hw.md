# Variantes de hardware (generado por ref/hw_report.sh, 2000 ticks de tb/practica.csv, periodo ronda 3)

| variante | LUTs | celdas logicas | BRAM | Fmax (MHz) | ciclos prom | ciclos max | IC prom | CPI |
|---|---|---|---|---|---|---|---|---|
| V0 software (trade_sw.s) | 973 | 1152 | 12 | 46.81 | 82.41 | 100 | 36.63 | 2.249 |
| V0b software, periféricos lite | 868 | 1033 | 12 | 47.03 | 82.41 | 100 | 36.63 | 2.249 |
| V1 acelerador SMA (trade_hw.s) | 994 | 1195 | 13 | 42.03 | 51.82 | 564 | 21.12 | 2.453 |
| V2 shifter parcial + EMA adaptativa (trade.s) FINAL | 1040 | 1205 | 12 | 45.28 | 61.69 | 75 | 27.51 | 2.242 |

V1: el ciclo max (564) es el primer tick: la FSM rellena el anillo de 512 bytes con p0. Sin contar el primer tick el max es 64.
Speedup medido V0->V1: 82.41/51.82 = 1.59x; V0->V2: 82.41/61.69 = 1.34x. La V2 agrega detección de saltos y bloqueo adaptativo, pero mantiene un amplio margen frente a la ronda 3. PLL: la Go Board (iCE40 HX1K) no tiene PLL (nextpnr: no suitable BEL).
