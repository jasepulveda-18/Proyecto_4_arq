// Testbench del acelerador pochoco_sma: compara d contra el calculo directo 4*SUM128 - SUM512.
//   iverilog -g2012 -s tb_sma -o /tmp/tb_sma rtl/pochoco_sma.v tb/tb_sma.sv && vvp -n /tmp/tb_sma
`timescale 1ns/1ps
module tb_sma;
  localparam int NT = 3000;
  logic clk = 0; always #20 clk = ~clk;
  logic rst_ni = 0, sel = 0, req = 0, we = 0; logic [7:0] addr = 0; logic [31:0] wdata = 0; wire [31:0] rdata;
  pochoco_sma dut(.clk_i(clk), .rst_ni(rst_ni), .sel_i(sel), .req_i(req), .we_i(we),
                  .addr_i(addr), .wdata_i(wdata), .rdata_o(rdata));
  int precio [NT]; int hist [NT];
  int fd, t, r, errores = 0; string enc;
  task automatic bus(input bit w, input [7:0] a, input [31:0] d);
    @(negedge clk); sel = 1; req = 1; we = w; addr = a; wdata = d;
    @(negedge clk); sel = 0; req = 0; we = 0;
  endtask
  initial begin
    fd = $fopen("tb/practica.csv", "r"); r = $fgets(enc, fd);
    for (int n = 0; n < NT; n++) r = $fscanf(fd, "%d,%d\n", t, precio[n]);
    repeat (4) @(posedge clk); rst_ni = 1; repeat (2) @(posedge clk);
    for (int n = 0; n < NT; n++) begin
      int s1, s2, esperado;
      s1 = 0; s2 = 0;
      hist[n] = precio[n];
      for (int k = 0; k < 128; k++) s1 += (n-k >= 0) ? hist[n-k] : precio[0];
      for (int k = 0; k < 512; k++) s2 += (n-k >= 0) ? hist[n-k] : precio[0];
      esperado = 4*s1 - s2;
      bus(1, 8'h00, precio[n]);
      do bus(0, 8'h00, 0); while (rdata[0]);            // espera !ocupado
      bus(0, 8'h04, 0); @(negedge clk);
      if ($signed(rdata) !== esperado) begin errores++; if (errores < 5) $display("tick %0d: d=%0d esperado=%0d", n, $signed(rdata), esperado); end
    end
    $display("%s: %0d ticks, %0d errores", errores == 0 ? "PASS" : "FAIL", NT, errores);
    $finish;
  end
endmodule
