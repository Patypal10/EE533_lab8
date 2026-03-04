///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: module_template 2008-03-13 gac1 $
//
// Module: ids.v
// Project: NF2.1
// Description: Defines a simple ids module for the user data path.  The
// modules reads a 64-bit register that contains a pattern to match and
// counts how many packets match.  The register contents are 7 bytes of
// pattern and one byte of mask.  The mask bits are set to one for each
// byte of the pattern that should be included in the mask -- zero bits
// mean "don't care".
//
///////////////////////////////////////////////////////////////////////////////
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
      
      // --- Register interface
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

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

   reg [7:0] head, tail;
   reg tail_wrapped;
   wire full, empty;

   wire fifo_we;

   wire [7:0] fifo_addr_in;
   wire [7:0] cpu_addr_in;
   wire [63:0] cpu_data_in, cpu_data_out;

   assign wire [7:0] tail_next = (tail == 8'hff) ? 0 : tail + 1;
   assign wire [7:0] head_next = (head == 8'hff) ? 0 : head + 1;

   assign wire [7:0] fifo_addr_in = (state == FLUSH) ? head : tail;

   assign wire empty = (head == tail) && !tail_wrapped;
   assign wire full = (head == tail) && tail_wrapped;

   // REG INTERFACE WILL BE EXPOSED PORTS
   wire done_process;

   
   FIFO_bram FIFO_bram_i (
      .addra(fifo_addr_in),   // FOR FIFO OP
      .addrb(cpu_addr_in),               // DMEM ACCESS FROM CPU
      .clka (clk),
      .clkb (clk),
      .dina({in_ctrl, in_data}),
      .dinb({8'h00, cpu_data_in}),
      .douta({out_ctrl, out_data}),
      .doutb(cpu_data_out),
      .wea(fifo_we),
      .web(cpu_we)
   );
   

   // State machine / controller
   always @(*) begin
      state_next = state;
      fifo_we = 0;
      out_wr = 0;

      case (state)
         START: begin
            if (in_ctrl != 0) begin
               state_next = CAPTURE;
               fifo_we = 1;
            end
         end
         CAPTURE : begin
            if (in_ctrl != 0) begin
               state_next = PROCESS;
            end
            if (!full) begin
               fifo_we = 1;
            end
         end
         PROCESS : begin
            if (done_process) begin
               state_next = FLUSH;
            end
         end
         FLUSH : begin
            if (empty) begin
               state_next = START;
               out_wr = 0;
            end else begin
               out_wr = 1;
            end
         end
      endcase
   end
   
   always @(posedge clk) begin
      if(reset) begin
         head <= 0;
         tail <= 0;
         state <= START;
      end else begin
         state <= state_next;

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

      end
   end
   
   
   generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`IDS_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`IDS_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                 // Number of counters
      .NUM_SOFTWARE_REGS   (3),                 // Number of sw regs
      .NUM_HARDWARE_REGS   (1)                  // Number of hw regs
   ) module_regs (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      // --- counters interface
      .counter_updates  (),
      .counter_decrement(),

      // --- SW regs interface
      .software_regs    ({ids_cmd,pattern_low,pattern_high}),

      // --- HW regs interface
      .hardware_regs    (matches),

      .clk              (clk),
      .reset            (reset)
    );


endmodule 
