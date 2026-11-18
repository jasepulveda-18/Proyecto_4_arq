# Proyecto 4 - Pochoco Trader, variante V0: solo software (SMA128/SMA512, RTL base del Espino)
#
# Estrategia: seguimiento de tendencia largo/efectivo.
#   S1 = suma de los ultimos 128 precios, S2 = suma de los ultimos 512 (anillo de bytes en RAM).
#   d  = 4*S1 - S2 = 512*(SMA128 - SMA512).   d > +512 -> largo;  d < -512 -> efectivo.
#   Al cambiar de estado se envian 6 ordenes de 63 acciones (la maestra recorta a lo posible:
#   comprar = "lo que alcance", vender = "lo que haya"; ordenes sin efecto no pagan comision).
# Sin shifts ni multiplicaciones: 128*p y 512*p se obtienen duplicando (add), 4*S1 con 2 add.
#
# Registros:  x1=base SPI  x2=indice de escritura del anillo  x3=n (ticks vistos, satura en 512)
#   x4=p0 (primer precio)  x5=S1  x6=S2  x7=estado largo(1)/efectivo(0)  x8=rafagas pendientes
#   x9=libre  x10=precio  x11..x13=temporales
# Memoria: anillo de 512 BYTES (un precio por byte, lbu/sb) en 0x400-0x5FF; x2 = indice 0..511.
# SPI: 0x80010000 STATUS(bit0=precio nuevo) / +4 PRICE (leerlo lo consume) / +8 DECISION.

.section .text
.global _start

_start:
    lui  x1, 0x80010
    addi x2, x0, 0            # indice de escritura = 0
    addi x3, x0, 0            # n = 0
    addi x7, x0, 1            # estado inicial: largo (como comprar y mantener)
    addi x8, x0, 6            # rafaga inicial de compra
    addi x5, x0, 0
    addi x6, x0, 0
    sw   x0, 8(x1)            # DECISION = mantener hasta el primer precio

wait_price:
    lw   x11, 0(x1)
    andi x11, x11, 1
    beq  x11, x0, wait_price
    lw   x10, 4(x1)           # x10 = p_n (consume el precio)

    bne  x3, x0, update
    # --- primer precio: p0, S1 = 128*p, S2 = 512*p (por duplicacion) ---
    addi x4, x10, 0
    add  x5, x10, x10         # 2p
    add  x5, x5, x5           # 4p
    add  x5, x5, x5           # 8p
    add  x5, x5, x5           # 16p
    add  x5, x5, x5           # 32p
    add  x5, x5, x5           # 64p
    add  x5, x5, x5           # 128p
    add  x6, x5, x5           # 256p
    add  x6, x6, x6           # 512p

update:
    # old2 = (n < 512) ? p0 : buf[idx]
    addi x11, x4, 0
    sltiu x12, x3, 512
    bne  x12, x0, have_old2
    lbu  x11, 1024(x2)
have_old2:
    # old1 = (n < 128) ? p0 : buf[(idx - 128) & 511]
    addi x12, x4, 0
    sltiu x13, x3, 128
    bne  x13, x0, have_old1
    addi x12, x2, -128
    andi x12, x12, 511
    lbu  x12, 1024(x12)
have_old1:
    sb   x10, 1024(x2)        # buf[idx] = p
    sub  x13, x10, x12
    add  x5, x5, x13          # S1 += p - old1
    sub  x13, x10, x11
    add  x6, x6, x13          # S2 += p - old2
    addi x2, x2, 1            # idx = (idx + 1) & 511
    andi x2, x2, 511
    sltiu x11, x3, 512        # if n < 512: n++
    beq  x11, x0, signal
    addi x3, x3, 1

signal:
    add  x11, x5, x5
    add  x11, x11, x11
    sub  x11, x11, x6         # d = 4*S1 - S2
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
    addi x11, x0, 0           # decision = mantener
    beq  x8, x0, write
    addi x8, x8, -1
    addi x11, x0, 0x7F        # comprar 63
    bne  x7, x0, write
    addi x11, x0, 0xBF        # vender 63
write:
    sw   x11, 8(x1)
    jal  x0, wait_price
