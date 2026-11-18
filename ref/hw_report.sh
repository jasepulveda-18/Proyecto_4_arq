#!/bin/bash
# Genera la tabla de variantes: LUTs, celdas logicas, BRAM, Fmax (nextpnr) y ciclos/IC/CPI por tick.
# Uso (desde la raiz del repo):  bash ref/hw_report.sh        Requiere oss-cad-suite en el PATH.
set -e
SIM=$(yosys-config --datdir)/ice40/cells_sim.v
printf "| variante | LUTs | celdas logicas | BRAM | Fmax (MHz) | ciclos prom | ciclos max | IC prom | CPI |\n|---|---|---|---|---|---|---|---|---|\n"
row() { # nombre top hex flag
  yosys -q -p "read_verilog rtl/*.v rtl/espino_core/*.v; synth_ice40 -top $2 -json /tmp/hw_$2.json; tee -o /tmp/hw_$2.stat stat" >/dev/null 2>&1
  luts=$(grep -E "SB_LUT4" /tmp/hw_$2.stat | tail -1 | awk '{print $1}')
  nextpnr-ice40 --hx1k --package vq100 --freq 25 --json /tmp/hw_$2.json --pcf goboard.pcf --asc /tmp/hw_$2.asc > /tmp/hw_$2.log 2>&1 || true
  lc=$(grep "ICESTORM_LC:" /tmp/hw_$2.log | tail -1 | sed -E 's/.*: *([0-9]+)\/.*/\1/'); ram=$(grep "ICESTORM_RAM:" /tmp/hw_$2.log | tail -1 | sed -E 's/.*: *([0-9]+)\/.*/\1/')
  fmax=$(grep "Max frequency" /tmp/hw_$2.log | tail -1 | sed -E 's/.*: ([0-9.]+) MHz.*/\1/')
  iverilog -g2012 $4 -s tb_metrics -o /tmp/hw_tb $SIM rtl/*.v rtl/espino_core/*.v tb/tb_metrics.sv 2>/dev/null
  m=$(vvp -n /tmp/hw_tb | grep ticks=)
  cm=$(echo "$m" | sed -E 's/.*prom=([0-9.]+) min=[0-9]+ max=([0-9]+) \| IC: prom=([0-9.]+) max=[0-9]+ \| CPI prom=([0-9.]+).*/\1 \2 \3 \4/')
  read c_avg c_max ic_avg cpi <<< "$cm"
  echo "| $1 | $luts | $lc | $ram | $fmax | $c_avg | $c_max | $ic_avg | $cpi |"
}
row "V0 software (trade_sw.s)"            trade_sw_top    sw/trade_sw.hex "-DSW"
row "V0b software, periféricos lite"      trade_sw_lite_top sw/trade_sw.hex "-DSW"
row "V1 acelerador SMA (trade_hw.s)"      trade_hw_top    sw/trade_hw.hex "-DSMA"
row "V2 shifter parcial + EMA (trade.s) FINAL" trade_top sw/trade.hex ""
