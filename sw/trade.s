# Proyecto 4 - Programa base de Pochoco Trader
#
# Mapa del periferico SPI:
#   0x80010000: STATUS   (bit 0 = hay un precio nuevo)
#   0x80010004: PRICE    (leerlo consume el precio pendiente)
#   0x80010008: DECISION (byte que se respondera en la proxima trama SPI)
#
# Formato de DECISION:
#   bits 7:6 = accion (00 mantener, 01 comprar, 10 vender)
#   bits 5:0 = cantidad (0 a 63)
#
# Esta primera version siempre responde mantener. Su objetivo es comprobar
# el recorrido completo antes de implementar la estrategia de trading.

.section .text
.global _start

_start:
    lui  x2, 0x80010       # x2 = base del periferico SPI
    addi x3, x2, 0         # x3 = STATUS
    addi x4, x2, 4         # x4 = PRICE
    addi x5, x2, 8         # x5 = DECISION

wait_price:
    lw   x6, 0(x3)         # leer estado del SPI
    andi x6, x6, 1         # conservar new_price
    beq  x6, x0, wait_price

    lw   x7, 0(x4)         # leer y reconocer el precio nuevo
    sw   x0, 0(x5)         # 0x00 = mantener, cantidad cero
    jal  x0, wait_price
