# Proyecto 4 — Pochoco Trader (co-diseño HW/SW sobre Espino Core)

Agente de inversión que corre en el Espino Core: recibe el precio por SPI, decide comprar / vender / mantener y escribe `DECISION`.
**Versión final (V2):** cruce de EMA rápida (α = 2⁻⁶) y lenta (α = 2⁻⁸), largo/efectivo con histéresis asimétrica (+3 para entrar y −5 para salir), sobre un ALU con shifter parcial.

## Contenido

| Ruta | Qué es |
|---|---|
| `sw/trade.s` | **Programa final (V2)**: EMA 64/256 con shifter parcial |
| `sw/trade_sw.s` | V0: solo software, SMA 128/512 con anillo de 512 bytes (sin cambios de RTL) |
| `sw/trade_hw.s` | V1: indicador SMA en el periférico `rtl/pochoco_sma.v` |
| `sw/assembler.py` | Assembler del grupo (agrega `lbu`, `sb`, `slli`, `srli`, `srai`) |
| `rtl/trade_top.v` | Top de la placa, versión final (`trade_sw_top.v`, `trade_sw_lite_top.v`, `trade_hw_top.v` para las otras variantes) |
| `rtl/pochoco_sma.v` | Acelerador de la variante V1 |
| `rtl/espino_core/espino_alu.v` | Parámetro `UseShifter`: SLL por 2, 6 y 8; SRL por 6 y 8 (el resto sigue como ADD) |
| `tb/tb_proyecto_4.sv` | Testbench oficial (emula la maestra) |
| `tb/tb_metrics.sv` | Mismo escenario + métricas por tick (ciclos, IC, CPI) y perfil por instrucción |
| `tb/tb_sma.sv` | Testbench del acelerador `pochoco_sma` |
| `ref/` | Referencias en Python: `market.py` (contabilidad oficial), `trader_ref.py` (V0/V1), `trader_ref_ema.py` (V2 final), `compare.py`, `hw_report.sh` |
| `informe/` | Fuente LaTeX (Overleaf), figuras y datos del informe |
| `docs/resultados_hw.md` | Tabla de variantes generada por `ref/hw_report.sh` |
| `tb/practica.csv` | Serie de práctica (Meta, 20 000 ticks, precios 100–255) |

## Cómo usar (desde la raíz del repositorio)

Herramientas probadas: Yosys 0.68+130, nextpnr-ice40 0.11.1 (`--hx1k --package vq100`), Icarus Verilog 14.0 (`-g2012`), Python 3.9.6 (numpy 2.0.2, matplotlib 3.9.4 solo para `informe/analisis.py`), oss-cad-suite en el `PATH`.

```bash
make trade            # ensambla trade.s, trade_sw.s y trade_hw.s con sw/assembler.py (no se usa un assembler externo)
make p4-test          # testbench oficial con la versión final (4 chequeos)
make test             # pruebas unitarias del assembler
make all              # sintetiza trade_top, place & route a 25 MHz, genera el bitstream y programa la Go Board
```

Para sintetizar otra variante: `make all TOP=trade_hw_top` (necesita `sw/trade_hw.hex`, se genera con `make trade`).

Testbenches adicionales:

```bash
iverilog -g2012 -s tb_sma -o /tmp/tb_sma rtl/pochoco_sma.v tb/tb_sma.sv && vvp -n /tmp/tb_sma     # acelerador V1
iverilog -g2012 -s tb_metrics -o /tmp/tb_m $(yosys-config --datdir)/ice40/cells_sim.v rtl/*.v rtl/espino_core/*.v tb/tb_metrics.sv && vvp -n /tmp/tb_m
#   variantes: -DSW (V0), -DSMA (V1); sin define = versión final. -DNT=20000 -DPER=20000 corre la serie completa más rápido.
bash ref/hw_report.sh   # tabla de LUTs, celdas lógicas, BRAM, Fmax, ciclos, IC y CPI por variante
```

### Versión de referencia y equivalencia

`ref/trader_ref_ema.py` es la referencia bit-exacta de `sw/trade.s` (`ref/trader_ref.py` lo es de V0 y V1). Para comprobar que el assembly toma **exactamente** las mismas decisiones en toda la serie:

```bash
make p4-test                                           # escribe decisiones.csv (2000 ticks)
python3 ref/compare.py tb/practica.csv decisiones.csv ema   # "diferencias: 0"
python3 ref/trader_ref_ema.py tb/practica.csv          # patrimonio, órdenes y pérdida máxima de la referencia
```

(Para V0/V1 omitir el tercer argumento `ema`.) Con `-DNT=20000` el chequeo cubre los 20 000 ticks.

## Resumen de resultados (serie de práctica de Meta, 20 000 ticks)

| Estrategia | Patrimonio final | Órdenes | Pérdida máx. |
|---|---|---|---|
| No operar | 10 000 | 0 | 0 |
| Comprar y mantener | 9 695 | 1 | 9 300 |
| V0 SMA 128/512 | 9 962 | 44 | 5 163 |
| **V2 EMA 64/256 (final)** | **13 234** | 16 | 4 374 |

| Variante | LUTs | Celdas lógicas (de 1280) | Fmax | Ciclos prom / máx | IC prom | CPI |
|---|---|---|---|---|---|---|
| V0 software | 973 | 1152 | 46,8 MHz | 82,4 / 100 | 36,6 | 2,25 |
| V1 acelerador SMA | 994 | 1195 | 42,0 MHz | 51,8 / 564 (1.er tick) | 21,1 | 2,45 |
| **V2 shifter + EMA** | 1040 | 1205 | 45,3 MHz | 50,6 / 63 | 22,2 | 2,28 |

Presupuesto de la ronda 3: 2262 ciclos. La PLL no es una opción en esta placa (el iCE40 HX1K no la tiene).

## Notas de diseño

- La maestra recorta las compras a lo que alcanza la caja y las ventas a lo que se tiene, y una orden sin efecto no paga comisión. Por eso el programa envía ráfagas de 6 órdenes de 63 acciones al cambiar de estado y no necesita llevar la contabilidad.
- Las variantes V1 y V2 usan `LitePeriph=1` (sin LEDs, displays ni contador de ciclos) para caber en 1280 celdas lógicas.
- Todo el hardware agregado tiene testbench: `tb_sma.sv` para el acelerador y `tb_metrics.sv` / `tb_proyecto_4.sv` (con comparación contra la referencia) para el ALU con shifter.
- Datos sintéticos para validar robustez: `ref/gen_series.py` (requiere precios diarios descargados a `/tmp/p4data/*.json`; no se usan dentro del diseño).

---

## Base heredada

El proyecto parte de **Pochoco SoC y Espino Core**, la misma base utilizada en
proyectos anteriores. Los ejemplos `game`, `blink`, `7seg` y
`buttons_leds` se conservan únicamente como referencia y no forman parte de
la estrategia final.

Para este proyecto, la comunicación relevante está mapeada en
`0x8001_0000`: el procesador consulta el estado SPI, lee `PRICE` y escribe
`DECISION`. `rtl/pochoco_spi_slave.v` implementa esa interfaz y
`tb/tb_proyecto_4.sv` reemplaza a la FPGA maestra durante la simulación local.
