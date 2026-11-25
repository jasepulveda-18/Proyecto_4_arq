// Testbench con metricas por tick (instrucciones, ciclos, CPI). Misma contabilidad que tb_proyecto_4.
//   iverilog -g2012 -s tb_metrics [-DSW | -DSMA] [-DCLK_HALF=12] -o /tmp/tb_m $(yosys-config --datdir)/ice40/cells_sim.v rtl/*.v rtl/espino_core/*.v tb/tb_metrics.sv
//   vvp -n /tmp/tb_m         (escribe metricas.csv: tick,ciclos,ic)
`timescale 1ns/1ps
`ifndef CLK_HALF
 `define CLK_HALF 20            // 25 MHz; con PLL a 40 MHz: 12.5 -> usar -DCLK_HALF=12.5
`endif
`ifndef NT
 `define NT 2000
`endif
`ifndef PER
 `define PER 100000     // ronda 3; usar -DPER=20000 para simular rapido
`endif
module tb_metrics;
`ifdef SW
  localparam string PROGRAMA = "sw/trade_sw.hex"; localparam int USESMA = 0; localparam int USESHIFT = 0;
`elsif SMA
  localparam string PROGRAMA = "sw/trade_hw.hex"; localparam int USESMA = 1; localparam int USESHIFT = 0;
`else
  localparam string PROGRAMA = "sw/trade.hex";    localparam int USESMA = 0; localparam int USESHIFT = 1;   // version final
`endif
  localparam string SERIE = "tb/practica.csv";
  localparam int PERIODO_NS = `PER, NTICKS = `NT, CAJA0 = 10000, COMISION = 5, SPI_NS = 9500;
  logic clk = 0; always #(`CLK_HALF) clk = ~clk;
  logic sclk = 0, mosi = 0, cs_n = 1; wire miso;
  pochoco_soc #(.MemFile(PROGRAMA), .UseSma(USESMA), .UseShifter(USESHIFT)) dut (
    .i_Clk(clk), .o_LED(), .i_Switch(4'b0000),
    .o_Segment1_A(), .o_Segment1_B(), .o_Segment1_C(), .o_Segment1_D(), .o_Segment1_E(), .o_Segment1_F(), .o_Segment1_G(),
    .o_Segment2_A(), .o_Segment2_B(), .o_Segment2_C(), .o_Segment2_D(), .o_Segment2_E(), .o_Segment2_F(), .o_Segment2_G(),
    .i_SPI_SCLK(sclk), .i_SPI_MOSI(mosi), .i_SPI_CS_n(cs_n), .o_SPI_MISO(miso));
  int precio [20000];
  logic [7:0] rx;
  task automatic spi(input logic [7:0] enviar);
    cs_n = 0; #1000;
    for (int b = 7; b >= 0; b--) begin mosi = enviar[b]; #500 sclk = 1; rx[b] = (miso === 1'b1); #500 sclk = 0; end
    #500 cs_n = 1;
  endtask
  int ciclos = 0, ic = 0, tick = 0, fd, fm, t, r; bit esperando = 0; string enc;
  longint sum_c = 0, sum_i = 0; int max_c = 0, max_i = 0, n_resp = 0, min_c = 1<<30;
  int pc_cyc [0:511]; int pc_ic [0:511]; int tick_pc_sel;
  initial for (int i = 0; i < 512; i++) begin pc_cyc[i] = 0; pc_ic[i] = 0; end
  always @(posedge clk) begin
    if (esperando && n_resp > 0) begin
      pc_cyc[dut.u_core.pc_id[10:2]]++;
      if (dut.u_core.instr_valid_id && !dut.u_core.stall) pc_ic[dut.u_core.pc_id[10:2]]++;
    end
    ciclos++;
    if (dut.u_core.instr_valid_id && !dut.u_core.stall) ic++;
    if (dut.u_spi.byte_done) begin ciclos = 0; ic = 0; esperando = 1; end
    else if (esperando && dut.u_spi.wr && dut.u_spi.off == 2) begin
      $fdisplay(fm, "%0d,%0d,%0d", n_resp, ciclos, ic);
      sum_c += ciclos; sum_i += ic; n_resp++; esperando = 0;
      if (ciclos > max_c) max_c = ciclos; if (ciclos < min_c) min_c = ciclos; if (ic > max_i) max_i = ic;
    end
  end
  initial begin
    fd = $fopen(SERIE, "r"); r = $fgets(enc, fd);
    for (int n = 0; n < NTICKS; n++) r = $fscanf(fd, "%d,%d\n", t, precio[n]);
    fm = $fopen("metricas.csv", "w"); $fdisplay(fm, "tick,ciclos,ic");
    #12000;   // el reset de encendido del SoC dura ~10 us (contador de 8 bits): la maestra empieza despues
    fd = $fopen("decisiones.csv", "w"); $fdisplay(fd, "tick,precio,decision");
    for (int n = 0; n < NTICKS; n++) begin spi(precio[n]); $fdisplay(fd, "%0d,%0d,%02h", n, precio[n], rx); #(PERIODO_NS - SPI_NS); end
    $fclose(fd);
    $display("ticks=%0d  ciclos: prom=%0d.%02d min=%0d max=%0d | IC: prom=%0d.%02d max=%0d | CPI prom=%0d.%03d",
      n_resp, sum_c/n_resp, (sum_c*100/n_resp)%100, min_c, max_c, sum_i/n_resp, (sum_i*100/n_resp)%100, max_i,
      sum_c/sum_i, (sum_c*1000/sum_i)%1000);
    fd = $fopen("perfil_pc.csv", "w"); $fdisplay(fd, "pc,ciclos,ic");
    for (int i = 0; i < 512; i++) if (pc_cyc[i] != 0) $fdisplay(fd, "%0d,%0d,%0d", i*4, pc_cyc[i], pc_ic[i]);
    $fclose(fd);
    $finish;
  end
endmodule
