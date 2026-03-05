`timescale 1ns/1ps

module network_mem 
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output                              out_wr,
      input                               out_rdy,

      input [7:0] cpu_addr_in,
      input cpu_we,
		input done_process,
      
      // --- Register interface
      // input                               reg_req_in,
      // input                               reg_ack_in,
      // input                               reg_rd_wr_L_in,
      // input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      // input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      // input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      // output                              reg_req_out,
      // output                              reg_ack_out,
      // output                              reg_rd_wr_L_out,
      // output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      // output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      // output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // misc
      input                                reset,
      input                                clk
   );

    // local parameter
   parameter                     START = 2'b00;
   parameter                     CAPTURE = 2'b01;
   parameter                     PROCESS = 2'b10;
   parameter                     FLUSH = 2'b11;

   // internal signals
   reg [1:0] state, state_next;

   reg set_start_addr, set_end_addr;

   reg [7:0] head, tail;
   reg tail_wrapped;
	wire [7:0] tail_next, head_next;
   wire full, empty;
   reg fifo_we;
   wire [7:0] fifo_addr_in;
   reg read_req;

   assign tail_next = (tail == 8'hff) ? 0 : tail + 1;
   assign head_next = (head == 8'hff) ? 0 : head + 1;
   assign fifo_addr_in = (state == FLUSH) ? head : tail;

   assign empty = (head == tail) && !tail_wrapped;
   assign full = (head == tail) && tail_wrapped;

   // REG INTERFACE WILL BE EXPOSED PORTS
   //wire done_process;
   reg [7:0] pkt_start_addr, pkt_end_addr;
   // wire [7:0] cpu_addr_in;
   // wire cpu_we;
   reg [63:0] cpu_data_in;
	wire [63:0] cpu_data_out;
   reg [7:0] cpu_ctrl_in;
	wire [7:0] cpu_ctrl_out;

   assign in_rdy = (state == START) || ((state == CAPTURE) && !set_end_addr);
	assign out_wr = out_rdy && read_req;
   
   FIFO_bram FIFO_bram_i (
      .addra(fifo_addr_in),   // FOR FIFO OP
      .addrb(cpu_addr_in),    // DMEM ACCESS FROM CPU
      .clka (clk),
      .clkb (clk),
      .dina({in_ctrl, in_data}),
      .dinb({cpu_ctrl_in, cpu_data_in}),
      .douta({out_ctrl, out_data}),
      .doutb({cpu_ctrl_out, cpu_data_out}),
      .wea(in_wr && fifo_we),
      .web(cpu_we)
   );
   

   // State machine / controller
   always @(*) begin
      state_next = state;
      fifo_we = 0;
      set_start_addr = 0;
      set_end_addr = 0;

      cpu_data_in = 0;
      cpu_ctrl_in = 0;

      case (state)
         START: begin
            if (in_ctrl != 0) begin
               state_next = CAPTURE;
               fifo_we = 1;
               set_start_addr = 1;
            end
         end
         CAPTURE : begin
            if (in_ctrl != 0) begin
               state_next = PROCESS;
               set_end_addr = 1;
            end
            if (!full) begin
               fifo_we = 1;
            end
         end
         PROCESS : begin
            if (done_process) begin
               state_next = FLUSH;
            end
            cpu_data_in = cpu_data_out + 5;
            cpu_ctrl_in = cpu_ctrl_out;
         end
         FLUSH : begin
            if (head == pkt_end_addr) begin
               state_next = START;
            end
         end
      endcase
   end
   
   always @(posedge clk) begin
      if(reset) begin
         head <= 0;
         tail <= 0;
         tail_wrapped <= 0;
         state <= START;
         pkt_start_addr <= 0;
         pkt_end_addr <= 0;
         read_req <= 0;
      end else begin
         state <= state_next;

         // Set start addr reg
         if (set_start_addr) pkt_start_addr <= tail;

         // Set end addr reg
         if (set_end_addr || full) pkt_end_addr <= tail;

         // Increment tail pointer logic
         if (((state == START) && (in_ctrl != 0)) || ((state == CAPTURE) && (!full))) tail <= tail_next;

         // Increment head pointer logic
         if ((state == FLUSH) && (out_rdy && !empty)) head <= head_next;
         
         // tail wrapped logic
         if (tail == head_next) begin
            tail_wrapped <= 0;
         end else if (tail_next == head) begin
            tail_wrapped <= 1;
         end

         // Read out fifo logic, register the read request (basically if its in flush state) for one cycle to match 1 cycle latency of BRAM in order to match out_wr with when data is available
         read_req <= (state == FLUSH) && !empty;

      end
   end
   
   
   // generic_regs
   // #( 
   //    .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
   //    .TAG                 (`IDS_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
   //    .REG_ADDR_WIDTH      (`IDS_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
   //    .NUM_COUNTERS        (0),                 // Number of counters
   //    .NUM_SOFTWARE_REGS   (3),                 // Number of sw regs
   //    .NUM_HARDWARE_REGS   (1)                  // Number of hw regs
   // ) module_regs (
   //    .reg_req_in       (reg_req_in),
   //    .reg_ack_in       (reg_ack_in),
   //    .reg_rd_wr_L_in   (reg_rd_wr_L_in),
   //    .reg_addr_in      (reg_addr_in),
   //    .reg_data_in      (reg_data_in),
   //    .reg_src_in       (reg_src_in),

   //    .reg_req_out      (reg_req_out),
   //    .reg_ack_out      (reg_ack_out),
   //    .reg_rd_wr_L_out  (reg_rd_wr_L_out),
   //    .reg_addr_out     (reg_addr_out),
   //    .reg_data_out     (reg_data_out),
   //    .reg_src_out      (reg_src_out),

   //    // --- counters interface
   //    .counter_updates  (),
   //    .counter_decrement(),

   //    // --- SW regs interface
   //    .software_regs    ({ids_cmd,pattern_low,pattern_high}),

   //    // --- HW regs interface
   //    .hardware_regs    (matches),

   //    .clk              (clk),
   //    .reset            (reset)
   //  );


endmodule