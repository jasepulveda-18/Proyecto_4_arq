// Periferico MMIO del Proyecto 4: acelerador del indicador de tendencia (version compacta).
//   d = 4*SUM128 - SUM512 = 512*(SMA128 - SMA512), actualizado en forma incremental:
//   d += 3*p + old512 - 4*old128   (old = precio de hace 512/128 ticks).
// Con el primer precio, una FSM rellena el anillo de 512 bytes con p0 (512 ciclos), y d = 0.
// Un solo sumador de 18 bits en serie (5 ciclos por precio). El Espino sigue decidiendo: lee d,
// aplica histeresis y escribe DECISION.
//   0x00 escritura: precio nuevo      0x00 lectura: bit0 = ocupado      0x04 lectura: d con signo
module pochoco_sma (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire        sel_i,
  input  wire        req_i,
  input  wire        we_i,
  input  wire [7:0]  addr_i,
  input  wire [31:0] wdata_i,
  output wire [31:0] rdata_o
);
  wire access = sel_i & req_i;
  wire wr     = access & we_i & (addr_i[7:2] == 6'd0);

  localparam [2:0] IDLE = 3'd0, FILL = 3'd1, S1 = 3'd2, S2 = 3'd3, S3 = 3'd4, S4 = 3'd5, S5 = 3'd6;

  reg [7:0]  mem [0:511];            // anillo de precios (1 bloque de RAM)
  reg [8:0]  idx;
  reg [7:0]  p_q, rdat;
  reg        first;                  // aun no llega el primer precio
  reg signed [17:0] d;
  reg [2:0]  st;

  wire [8:0] raddr = (st == S2) ? {idx[8:7] + 2'd3, idx[6:0]} : idx;   // idx - 128 (mod 512)

  always @(posedge clk_i) begin
    rdat <= mem[raddr];
    if (st == FILL || st == S3) mem[idx] <= p_q;
  end

  // operando del sumador segun el paso
  reg [17:0] b; reg sub;
  always @* begin
    b = 18'd0; sub = 1'b0;
    case (st)
      S2: b = {10'd0, rdat};                  // + old512
      S3: begin b = {8'd0, rdat, 2'b00}; sub = 1'b1; end  // - 4*old128
      S4: b = {10'd0, p_q};                   // + p
      S5: b = {9'd0, p_q, 1'b0};              // + 2p
      default: ;
    endcase
  end

  wire [17:0] sum = d + (b ^ {18{sub}}) + {17'd0, sub};   // un solo sumador/restador

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      idx <= 9'd0; p_q <= 8'd0; first <= 1'b1; d <= 18'sd0; st <= IDLE;
    end else begin
      case (st)
        IDLE: if (wr) begin p_q <= wdata_i[7:0]; st <= first ? FILL : S1; first <= 1'b0; end
        FILL: begin idx <= idx + 9'd1; if (idx == 9'd511) st <= S1; end
        S1:   st <= S2;                       // emite lectura de buf[idx]
        S2:   begin d <= sum; st <= S3; end   // lectura de buf[idx-128] en curso; suma old512
        S3:   begin d <= sum; st <= S4; end   // resta 4*old128 (escribe buf[idx] = p)
        S4:   begin d <= sum; st <= S5; end
        S5:   begin d <= sum; idx <= idx + 9'd1; st <= IDLE; end
        default: st <= IDLE;
      endcase
    end
  end

  assign rdata_o = (addr_i[7:2] == 6'd0) ? {31'b0, st != IDLE} : {{14{d[17]}}, d};
endmodule
