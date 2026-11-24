# Proyecto 4 - Pochoco Trader, VERSION FINAL (V2): shifter parcial en el ALU (UseShifter=1) y estrategia adaptativa.
#   SF = 64*EMA_rapida (alfa = 1/64), SS = 256*EMA_lenta (alfa = 1/256)
#   SF += p - (SF >> 6);  SS += p - (SS >> 8);   d = 4*SF - SS = 256*(EMA_r - EMA_l)
#   Normal: d > +1280 -> largo; d < -2048 -> efectivo (histeresis +5/-8).
#   Un salto de precio >10 tiene prioridad y bloquea su direccion por 1600 ticks.
#   Mientras dure el estado se repite una orden de 63 acciones. Asi funciona
#   para todo el rango permitido de precios (1..255), sin conocer caja ni serie.
# No necesita anillo de precios en RAM. Referencia exacta: ref/trader_ref_ema.py.
# Registros: x1=base SPI x2=precio anterior x3=primer precio pendiente x4=bloqueo
#            x5=SF x6=SS x7=largo x10=precio x11..x13=temp

.section .text
.global _start

_start:
    lui  x1, 0x80010
    addi x3, x0, 1            # falta el primer precio
    addi x7, x0, 1            # estado inicial: largo
    sw   x0, 8(x1)

wait_price:
    lw   x11, 0(x1)
    andi x11, x11, 1
    beq  x11, x0, wait_price
    lw   x10, 4(x1)
    beq  x3, x0, update
    slli x5, x10, 6           # SF = 64*p0
    slli x6, x10, 8           # SS = 256*p0
    addi x2, x10, 0           # precio anterior = p0 (evita un salto falso al iniciar)
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

    sub  x12, x10, x2         # variacion desde el tick anterior
    addi x2, x10, 0
    slti x13, x12, 11         # variacion < +11 ?
    bne  x13, x0, not_jump_up
    addi x4, x0, 1600         # salto positivo: seguir largo durante 1600 ticks
    addi x13, x0, 1
    jal  x0, set_state
not_jump_up:
    slti x13, x12, -10        # variacion < -10 ?
    beq  x13, x0, no_jump
    addi x4, x0, 1600         # salto negativo: quedar en efectivo durante 1600 ticks
    addi x13, x0, 0
    jal  x0, set_state
no_jump:
    beq  x4, x0, check_ema
    addi x4, x4, -1
    jal  x0, emit

check_ema:
    slti x12, x11, 1281       # d <= 1280 ? (EMA_r - EMA_l <= 5)
    bne  x12, x0, not_up
    addi x13, x0, 1
    jal  x0, set_state
not_up:
    slti x12, x11, -2048      # d < -2048 ? (EMA_r - EMA_l < -8)
    beq  x12, x0, emit
    addi x13, x0, 0
set_state:
    addi x7, x13, 0

emit:
    addi x11, x0, 0x7F        # comprar 63
    bne  x7, x0, write
    addi x11, x0, 0xBF        # vender 63
write:
    sw   x11, 8(x1)
    jal  x0, wait_price
