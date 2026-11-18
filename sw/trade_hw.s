# Proyecto 4 - Pochoco Trader, variante HW-1: indicador de tendencia en el periferico pochoco_sma.
# Misma estrategia y mismas decisiones que trade.s. El anillo de 512 precios y la actualizacion
# d = 4*SUM128 - SUM512 viven en hardware (0x80020000); el Espino lee d, aplica la histeresis
# (+-512), mantiene el estado largo/efectivo y escribe DECISION.
#   0x80020000: escritura = precio nuevo; lectura bit0 = ocupado     0x80020004: d con signo
# Registros: x1=base SPI  x14=base SMA  x7=estado largo  x8=rafagas pendientes  x10=precio  x11..x13=temp

.section .text
.global _start

_start:
    lui  x1, 0x80010
    lui  x14, 0x80020
    addi x7, x0, 1            # estado inicial: largo
    addi x8, x0, 6            # rafaga inicial de compra
    sw   x0, 8(x1)

wait_price:
    lw   x11, 0(x1)
    andi x11, x11, 1
    beq  x11, x0, wait_price
    lw   x10, 4(x1)           # precio (consume el aviso)
    sw   x10, 0(x14)          # al acelerador

wait_acc:
    lw   x11, 0(x14)
    andi x11, x11, 1
    bne  x11, x0, wait_acc
    lw   x11, 4(x14)          # d = 4*S1 - S2

    slti x12, x11, 513        # d <= 512 ?
    bne  x12, x0, not_up
    addi x13, x0, 1           # d > 512 -> largo
    jal  x0, set_state
not_up:
    slti x12, x11, -512       # d < -512 ?
    beq  x12, x0, emit        # banda muerta: se conserva el estado
    addi x13, x0, 0           # efectivo
set_state:
    beq  x13, x7, emit
    addi x7, x13, 0
    addi x8, x0, 6            # nueva rafaga

emit:
    addi x11, x0, 0
    beq  x8, x0, write
    addi x8, x8, -1
    addi x11, x0, 0x7F        # comprar 63
    bne  x7, x0, write
    addi x11, x0, 0xBF        # vender 63
write:
    sw   x11, 8(x1)
    jal  x0, wait_price
