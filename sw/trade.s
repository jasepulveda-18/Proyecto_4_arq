# Proyecto 4 - Pochoco Trader, VERSION FINAL (V2): shifter parcial en el ALU (UseShifter=1) y estrategia EMA.
#   SF = 64*EMA_rapida (alfa = 1/64), SS = 256*EMA_lenta (alfa = 1/256)
#   SF += p - (SF >> 6);  SS += p - (SS >> 8);   d = 4*SF - SS = 256*(EMA_r - EMA_l)
#   d > +384 -> largo;  d < -384 -> efectivo (banda 1.5);  al cambiar: 6 ordenes de 63 acciones.
# No necesita anillo de precios en RAM. Referencia exacta: ref/trader_ref_ema.py.
# Registros: x1=base SPI x3=primer precio pendiente x5=SF x6=SS x7=largo x8=rafagas x10=precio x11..x13=temp

.section .text
.global _start

_start:
    lui  x1, 0x80010
    addi x3, x0, 1            # falta el primer precio
    addi x7, x0, 1            # estado inicial: largo
    addi x8, x0, 6            # rafaga inicial de compra
    sw   x0, 8(x1)

wait_price:
    lw   x11, 0(x1)
    andi x11, x11, 1
    beq  x11, x0, wait_price
    lw   x10, 4(x1)
    beq  x3, x0, update
    slli x5, x10, 6           # SF = 64*p0
    slli x6, x10, 8           # SS = 256*p0
    addi x3, x0, 0

update:
    srli x11, x5, 6
    sub  x11, x10, x11
    add  x5, x5, x11          # SF += p - (SF >> 6)
    srli x11, x6, 8
    sub  x11, x10, x11
    add  x6, x6, x11          # SS += p - (SS >> 8)
    slli x11, x5, 2
    sub  x11, x11, x6         # d = 4*SF - SS

    slti x12, x11, 385        # d <= 384 ?
    bne  x12, x0, not_up
    addi x13, x0, 1
    jal  x0, set_state
not_up:
    slti x12, x11, -384       # d < -384 ?
    beq  x12, x0, emit
    addi x13, x0, 0
set_state:
    beq  x13, x7, emit
    addi x7, x13, 0
    addi x8, x0, 6

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
