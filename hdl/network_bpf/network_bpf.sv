`timescale 1ns / 1ps `default_nettype none

module network_bpf
  import network_bpf_config_pkg::*;
(
    input wire rst,

    // Port 1 (Ingress)
    input wire eth1_clk,
    input wire eth1_crsdv,
    input wire [1:0] eth1_rxd,
    output logic eth1_txen,
    output logic [1:0] eth1_txd,

    // Port 2 (Egress)
    input wire eth2_clk,
    input wire eth2_crsdv,
    input wire [1:0] eth2_rxd,
    output logic eth2_txen,
    output logic [1:0] eth2_txd,

    // Statistics output 
    output logic [31:0] o_total_bytes,
    output logic [31:0] o_received_packets,
    output logic [31:0] o_sent_packets
);

  // ------------------------------------------------------------------------
  // Internal FIFO Interfaces 
  // ------------------------------------------------------------------------

  // --- 1. Free Buffer FIFO (buffer IDs) ---
  logic         [NUM_CPUS-1:0][   BUF_ID_BITS-1:0] free_buf_push_data;
  logic         [NUM_CPUS-1:0]                     free_buf_push_valid;
  logic         [NUM_CPUS-1:0]                     free_buf_push_ready;
  logic         [NUM_CPUS-1:0][   BUF_ID_BITS-1:0] free_buf_pop_data;
  logic         [NUM_CPUS-1:0]                     free_buf_pop_valid;
  logic         [NUM_CPUS-1:0]                     free_buf_pop_ready;

  // --- 2. BPF Work FIFO (packet_desc_t) ---
  packet_desc_t [NUM_CPUS-1:0]                     bpf_work_push_data;
  logic         [NUM_CPUS-1:0]                     bpf_work_push_valid;
  logic         [NUM_CPUS-1:0]                     bpf_work_push_ready;
  packet_desc_t [NUM_CPUS-1:0]                     bpf_work_pop_data;
  logic         [NUM_CPUS-1:0]                     bpf_work_pop_valid;
  logic         [NUM_CPUS-1:0]                     bpf_work_pop_ready;

  // --- 3. TX Work FIFO (packet_desc_t) ---
  packet_desc_t [NUM_CPUS-1:0]                     tx_work_push_data;
  logic         [NUM_CPUS-1:0]                     tx_work_push_valid;
  logic         [NUM_CPUS-1:0]                     tx_work_push_ready;
  packet_desc_t [NUM_CPUS-1:0]                     tx_work_pop_data;
  logic         [NUM_CPUS-1:0]                     tx_work_pop_valid;
  logic         [NUM_CPUS-1:0]                     tx_work_pop_ready;

  // ------------------------------------------------------------------------
  // BRAM Interface Signals 
  // ------------------------------------------------------------------------
  // RX Write Ports
  logic         [NUM_CPUS-1:0]                     rx_wr_en;
  logic         [NUM_CPUS-1:0][BRAM_ADDR_BITS-1:0] rx_bram_addr;
  logic         [NUM_CPUS-1:0][    BRAM_WIDTH-1:0] rx_wr_data;
  logic         [NUM_CPUS-1:0][   BUF_ID_BITS-1:0] rx_buf_id;
  logic         [NUM_CPUS-1:0][ BUF_ADDR_BITS-1:0] rx_buf_addr;
  genvar i;
  generate
    for (i = 0; i < NUM_CPUS; i++) begin : rx_addr_gen
      assign rx_bram_addr[i] = {rx_buf_id[i], rx_buf_addr[i]};
    end
  endgenerate

  // BPF Read Port
  logic [NUM_CPUS-1:0]                     bpf_rd_en;
  logic [NUM_CPUS-1:0][BRAM_ADDR_BITS-1:0] bpf_bram_addr;
  logic [NUM_CPUS-1:0][    BRAM_WIDTH-1:0] bpf_rd_data;
  logic [NUM_CPUS-1:0][   BUF_ID_BITS-1:0] bpf_buf_id;
  logic [NUM_CPUS-1:0][ BUF_ADDR_BITS-1:0] bpf_buf_addr;
  generate
    for (i = 0; i < NUM_CPUS; i++) begin : bpf_addr_gen
      assign bpf_bram_addr[i] = {bpf_buf_id[i], bpf_buf_addr[i]};
    end
  endgenerate

  // TX Read Port
  logic [NUM_CPUS-1:0]                     tx_rd_en;
  logic [NUM_CPUS-1:0][BRAM_ADDR_BITS-1:0] tx_bram_addr;
  logic [NUM_CPUS-1:0][    BRAM_WIDTH-1:0] tx_rd_data;
  logic [NUM_CPUS-1:0][   BUF_ID_BITS-1:0] tx_buf_id;
  logic [NUM_CPUS-1:0][ BUF_ADDR_BITS-1:0] tx_buf_addr;
  generate
    for (i = 0; i < NUM_CPUS; i++) begin : tx_addr_gen
      assign tx_bram_addr[i] = {tx_buf_id[i], tx_buf_addr[i]};
    end
  endgenerate

  // ------------------------------------------------------------------------
  // Statistics Signals
  // ------------------------------------------------------------------------
  logic                   pkt_ingress_byte_active;
  logic                   pkt_ingress_received_pulse;
  logic                   pkt_ingress_sent_pulse;

  logic                   pkt_egress_byte_active;
  logic                   pkt_egress_received_pulse;
  logic                   pkt_egress_sent_pulse;

  // ========================================================================
  // RX SIDE (Ingress)
  // ========================================================================

  // 1. Free Buffer Mux (Many CPUs -> 1 RX)
  logic [CPU_ID_BITS-1:0] rx_mux_free_buf_pop_cpu_id;
  logic [BUF_ID_BITS-1:0] rx_mux_free_buf_pop_data;
  logic                   rx_mux_free_buf_pop_valid;
  logic                   rx_mux_free_buf_pop_ready;

  mux #(
      .DATA_WIDTH(BUF_ID_BITS)
  ) rx_mux (
      .clk(eth1_clk),
      .rst(rst),
      // Array Inputs
      .i_pop_data(free_buf_pop_data),
      .i_pop_valid(free_buf_pop_valid),
      .o_pop_ready(free_buf_pop_ready),
      // Single Output to eth_rx
      .o_mux_pop_cpu_id(rx_mux_free_buf_pop_cpu_id),
      .o_mux_pop_data(rx_mux_free_buf_pop_data),
      .o_mux_pop_valid(rx_mux_free_buf_pop_valid),
      .i_mux_pop_ready(rx_mux_free_buf_pop_ready)
  );

  // 2. BPF Work Demux (1 RX -> Many CPUs)
  logic         [CPU_ID_BITS-1:0] rx_demux_bpf_work_push_cpu_id;
  packet_desc_t                   rx_demux_bpf_work_push_data;
  logic                           rx_demux_bpf_work_push_valid;
  logic                           rx_demux_bpf_work_push_ready;

  demux #(
      .DATA_WIDTH($bits(packet_desc_t))
  ) rx_demux (
      .clk               (eth1_clk),
      .rst               (rst),
      // Single Input from eth_rx
      .i_demux_cpu_id    (rx_demux_bpf_work_push_cpu_id),
      .i_demux_push_data (rx_demux_bpf_work_push_data),
      .i_demux_push_valid(rx_demux_bpf_work_push_valid),
      .o_demux_push_ready(rx_demux_bpf_work_push_ready),
      // Array Outputs
      .o_push_data       (bpf_work_push_data),
      .o_push_valid      (bpf_work_push_valid),
      .i_push_ready      (bpf_work_push_ready)
  );

  // 3. BRAM Write Demux (1 RX -> Many BRAMs)
  logic                     rx_demux_bram_wr_en;
  logic [  CPU_ID_BITS-1:0] rx_demux_bram_cpu_id;
  logic [  BUF_ID_BITS-1:0] rx_demux_bram_buf_id;
  logic [BUF_ADDR_BITS-1:0] rx_demux_bram_wr_addr;
  logic [              7:0] rx_demux_bram_wr_data;

  bram_demux_write #(
      .DATA_WIDTH(8)
  ) rx_bram_demux (
      .clk           (eth1_clk),
      .rst           (rst),
      // Single Input from eth_rx
      .i_demux_cpu_id(rx_demux_bram_cpu_id),
      .i_demux_wr_en (rx_demux_bram_wr_en),
      .i_demux_buf_id(rx_demux_bram_buf_id),
      .i_demux_addr  (rx_demux_bram_wr_addr),
      .i_demux_data  (rx_demux_bram_wr_data),
      // Array Outputs
      .o_wr_en       (rx_wr_en),
      .o_wr_data     (rx_wr_data),
      .o_buf_id_out  (rx_buf_id),
      .o_addr_out    (rx_buf_addr)
  );

  // 4. RX Module Instantiation
  eth_rx eth_rx_inst (
      .clk(eth1_clk),
      .rst(rst),

      .eth_crsdv(eth1_crsdv),
      .eth_rxd  (eth1_rxd),

      // Free Buffer Interface (Muxed)
      .i_free_buf_pop_cpu_id(rx_mux_free_buf_pop_cpu_id),
      .i_free_buf_pop_data  (rx_mux_free_buf_pop_data),
      .i_free_buf_pop_valid (rx_mux_free_buf_pop_valid),
      .o_free_buf_pop_ready (rx_mux_free_buf_pop_ready),

      // Work Push Interface (Demuxed)
      .o_bpf_work_push_cpu_id(rx_demux_bpf_work_push_cpu_id),
      .o_bpf_work_push_data  (rx_demux_bpf_work_push_data),
      .o_bpf_work_push_valid (rx_demux_bpf_work_push_valid),
      .i_bpf_work_push_ready (rx_demux_bpf_work_push_ready),

      // BRAM Write Interface (Demuxed)
      .o_wren   (rx_demux_bram_wr_en),
      .o_cpu_id (rx_demux_bram_cpu_id),
      .o_buf_id (rx_demux_bram_buf_id),
      .o_wr_addr(rx_demux_bram_wr_addr),
      .o_wr_data(rx_demux_bram_wr_data),

      // Stats
      .o_byte_active       (pkt_ingress_byte_active),
      .o_pkt_received_pulse(pkt_ingress_received_pulse),
      .o_pkt_sent_pulse    (pkt_ingress_sent_pulse)
  );


  // ========================================================================
  // TX SIDE (Egress)
  // ========================================================================

  // 1. TX Work Mux/Arbiter (Many CPUs -> 1 TX)
  logic         [CPU_ID_BITS-1:0] tx_mux_tx_work_pop_cpu_id;
  packet_desc_t                   tx_mux_tx_work_pop_data;
  logic                           tx_mux_tx_work_pop_valid;
  logic                           tx_mux_tx_work_pop_ready;

  mux #(
      .DATA_WIDTH($bits(packet_desc_t))
  ) tx_work_mux (
      .clk(eth2_clk),
      .rst(rst),
      // Array Inputs
      .i_pop_data(tx_work_pop_data),
      .i_pop_valid(tx_work_pop_valid),
      .o_pop_ready(tx_work_pop_ready),
      // Single Output to eth_tx
      .o_mux_pop_cpu_id(tx_mux_tx_work_pop_cpu_id),
      .o_mux_pop_data(tx_mux_tx_work_pop_data),
      .o_mux_pop_valid(tx_mux_tx_work_pop_valid),
      .i_mux_pop_ready(tx_mux_tx_work_pop_ready)
  );

  // 2. Return Buffer Demux (1 TX -> Many Free Lists)
  logic [CPU_ID_BITS-1:0] tx_demux_free_buf_push_cpu_id;
  logic [BUF_ID_BITS-1:0] tx_demux_free_buf_push_data;
  logic                   tx_demux_free_buf_push_valid;
  logic                   tx_demux_free_buf_push_ready;

  demux #(
      .DATA_WIDTH(BUF_ID_BITS)
  ) tx_ret_demux (
      .clk               (eth2_clk),
      .rst               (rst),
      // Single Input from eth_tx
      .i_demux_cpu_id    (tx_demux_free_buf_push_cpu_id),
      .i_demux_push_data (tx_demux_free_buf_push_data),
      .i_demux_push_valid(tx_demux_free_buf_push_valid),
      .o_demux_push_ready(tx_demux_free_buf_push_ready),
      // Array Outputs (pushing back to free list)
      .o_push_data       (free_buf_push_data),
      .o_push_valid      (free_buf_push_valid),
      .i_push_ready      (free_buf_push_ready)
  );

  // 3. BRAM Read Mux (1 TX Reads -> Many BRAMs)
  logic                     tx_mux_bram_rd_en;
  logic [  CPU_ID_BITS-1:0] tx_mux_bram_cpu_id;
  logic [  BUF_ID_BITS-1:0] tx_mux_bram_buf_id;
  logic [BUF_ADDR_BITS-1:0] tx_mux_bram_rd_addr;
  logic [              7:0] tx_mux_bram_rd_data;

  bram_demux_read #(
      .DATA_WIDTH(8)
  ) tx_bram_mux (
      .clk         (eth2_clk),
      .rst         (rst),
      // Single Input from eth_tx (Control)
      .i_mux_rd_en (tx_mux_bram_rd_en),
      .i_mux_cpu_id(tx_mux_bram_cpu_id),
      .i_mux_buf_id(tx_mux_bram_buf_id),
      .i_mux_addr  (tx_mux_bram_rd_addr),
      // Array Connections (Control Out, Data In)
      .o_rd_en     (tx_rd_en),
      .o_buf_id_out(tx_buf_id),
      .o_addr_out  (tx_buf_addr),
      .i_rd_data   (tx_rd_data),
      // Single Output to eth_tx (Data)
      .o_mux_data  (tx_mux_bram_rd_data)
  );

  // 4. TX Module Instantiation
  eth_tx eth_tx_inst (
      .clk(eth2_clk),
      .rst(rst),
      .eth_txen(eth2_txen),
      .eth_txd(eth2_txd),

      // Work Pull Interface (Muxed)
      .i_tx_work_pop_cpu_id(tx_mux_tx_work_pop_cpu_id),
      .i_tx_work_pop_data  (tx_mux_tx_work_pop_data),
      .i_tx_work_pop_valid (tx_mux_tx_work_pop_valid),
      .o_tx_work_pop_ready (tx_mux_tx_work_pop_ready),

      // Return Buffer Interface (Demuxed)
      .o_free_buf_push_cpu_id(tx_demux_free_buf_push_cpu_id),
      .o_free_buf_push_data  (tx_demux_free_buf_push_data),
      .o_free_buf_push_valid (tx_demux_free_buf_push_valid),
      .i_free_buf_push_ready (tx_demux_free_buf_push_ready),

      // BRAM Read Interface (demuxed)
      .o_rd_en  (tx_mux_bram_rd_en),
      .o_cpu_id (tx_mux_bram_cpu_id),
      .o_buf_id (tx_mux_bram_buf_id),
      .o_rd_addr(tx_mux_bram_rd_addr),
      .i_rd_data(tx_mux_bram_rd_data),

      // Stats
      .o_byte_active       (pkt_egress_byte_active),
      .o_pkt_received_pulse(pkt_egress_received_pulse),
      .o_pkt_sent_pulse    (pkt_egress_sent_pulse)
  );

  // ------------------------------------------------------------------------
  // Parallel CPUs 
  // ------------------------------------------------------------------------
  generate
    for (i = 0; i < NUM_CPUS; i++) begin : cpu_block

      async_init_fifo #(
          .DATA_WIDTH(BUF_ID_BITS),
          .FIFO_DEPTH(FIFO_DEPTH),
          .INIT_COUNT(NUM_BUFFERS_PER_CPU)
      ) free_buf_fifo (
          .rst         (rst),
          // Push from ETH2 (Return from TX)
          .push_clk    (eth2_clk),
          .i_push_data (free_buf_push_data[i]),
          .i_push_valid(free_buf_push_valid[i]),
          .o_push_ready(free_buf_push_ready[i]),
          // Pop to ETH1 (RX Alloc)
          .pop_clk     (eth1_clk),
          .o_pop_data  (free_buf_pop_data[i]),
          .o_pop_valid (free_buf_pop_valid[i]),
          .i_pop_ready (free_buf_pop_ready[i])
      );

      fifo #(
          .DATA_WIDTH($bits(packet_desc_t)),
          .FIFO_DEPTH(FIFO_DEPTH)
      ) bpf_work_fifo (
          .clk(eth1_clk),
          .rst(rst),
          // Push from ETH1 (RX)
          .i_push_data(bpf_work_push_data[i]),
          .i_push_valid(bpf_work_push_valid[i]),
          .o_push_ready(bpf_work_push_ready[i]),
          // Pop to Processor
          .o_pop_data(bpf_work_pop_data[i]),
          .o_pop_valid(bpf_work_pop_valid[i]),
          .i_pop_ready(bpf_work_pop_ready[i])
      );

      async_fifo #(
          .DATA_WIDTH($bits(packet_desc_t)),
          .FIFO_DEPTH(FIFO_DEPTH)
      ) tx_work_fifo (
          .rst         (rst),
          // Push from Processor
          .push_clk    (eth1_clk),
          .i_push_data (tx_work_push_data[i]),
          .i_push_valid(tx_work_push_valid[i]),
          .o_push_ready(tx_work_push_ready[i]),
          // Pop to ETH2 (TX)
          .pop_clk     (eth2_clk),
          .o_pop_data  (tx_work_pop_data[i]),
          .o_pop_valid (tx_work_pop_valid[i]),
          .i_pop_ready (tx_work_pop_ready[i])
      );

      xilinx_true_dual_port_read_first_1_clock_ram #(
          .RAM_WIDTH(BRAM_WIDTH),
          .RAM_DEPTH(BRAM_DEPTH)
      ) bpf_packet_bram (
          .clka(eth1_clk),
          .addra(rx_bram_addr[i]),
          .dina(rx_wr_data[i]),
          .wea(rx_wr_en[i]),
          .ena(1'b1),
          .regcea(1'b1),
          .rsta(rst),
          .douta(),  // RX only writes
          .addrb(bpf_bram_addr[i]),
          .dinb(0),
          .web(1'b0),
          .enb(1'b1),
          .regceb(1'b1),
          .rstb(rst),
          .doutb(bpf_rd_data[i])
      );

      xilinx_true_dual_port_read_first_2_clock_ram #(
          .RAM_WIDTH(BRAM_WIDTH),
          .RAM_DEPTH(BRAM_DEPTH)
      ) tx_bram (
          .clka(eth1_clk),
          .addra(rx_bram_addr[i]),
          .dina(rx_wr_data[i]),
          .wea(rx_wr_en[i]),
          .ena(1'b1),
          .regcea(1'b1),
          .rsta(rst),
          .douta(),  // RX only writes
          .clkb(eth2_clk),
          .addrb(tx_bram_addr[i]),
          .dinb(0),
          .web(1'b0),
          .enb(1'b1),
          .regceb(1'b1),
          .rstb(rst),
          .doutb(tx_rd_data[i])
      );

      bpf_processor bpf_processor (
          .clk(eth1_clk),
          .rst(rst),

          .i_bpf_work_pop_data (bpf_work_pop_data[i]),
          .i_bpf_work_pop_valid(bpf_work_pop_valid[i]),
          .o_bpf_work_pop_ready(bpf_work_pop_ready[i]),

          .o_tx_work_push_data (tx_work_push_data[i]),
          .o_tx_work_push_valid(tx_work_push_valid[i]),
          .i_tx_work_push_ready(tx_work_push_ready[i]),

          .o_rd_en  (bpf_rd_en[i]),
          .o_buf_id (bpf_buf_id[i]),
          .o_rd_addr(bpf_buf_addr[i]),
          .i_rd_data(bpf_rd_data[i]),

          .o_pkt_bpf_dropped_pulse()
      );
    end
  endgenerate

  // ------------------------------------------------------------------------
  // Statistics
  // ------------------------------------------------------------------------
  logic [31:0] ingress_total_bytes, ingress_received_packets, ingress_sent_packets;
  logic [31:0] egress_total_bytes, egress_received_packets, egress_sent_packets;

  network_bpf_statistics ingress_stats (
      .clk(eth1_clk),
      .rst(rst),
      .i_byte_active(pkt_ingress_byte_active),
      .i_pkt_received(pkt_ingress_received_pulse),
      .i_pkt_sent(pkt_ingress_sent_pulse),

      .o_total_bytes(ingress_total_bytes),
      .o_received_packets(ingress_received_packets),
      .o_sent_packets(ingress_sent_packets)
  );

  network_bpf_statistics egress_stats (
      .clk(eth2_clk),
      .rst(rst),
      .i_byte_active(pkt_egress_byte_active),
      .i_pkt_received(pkt_egress_received_pulse),
      .i_pkt_sent(pkt_egress_sent_pulse),

      .o_total_bytes(egress_total_bytes),
      .o_received_packets(egress_received_packets),
      .o_sent_packets(egress_sent_packets)
  );

  assign o_total_bytes = {ingress_total_bytes[15:0], egress_total_bytes[15:0]};
  assign o_received_packets = {ingress_received_packets[15:0], egress_received_packets[15:0]};
  assign o_sent_packets = {ingress_sent_packets[15:0], egress_sent_packets[15:0]};

  // ------------------------------------------------------------------------
  // eth2 -> eth1 Pass-Through 
  // ------------------------------------------------------------------------
  
  logic [BUF_ID_BITS-1:0] rev_free_buf_pop_data;
  logic                   rev_free_buf_pop_valid;
  logic                   rev_free_buf_pop_ready;

  logic [BUF_ID_BITS-1:0] rev_free_buf_push_data;
  logic                   rev_free_buf_push_valid;
  logic                   rev_free_buf_push_ready;

  packet_desc_t           rev_work_push_data;
  logic                   rev_work_push_valid;
  logic                   rev_work_push_ready;

  packet_desc_t           rev_work_pop_data;
  logic                   rev_work_pop_valid;
  logic                   rev_work_pop_ready;

  logic                   rev_rx_wr_en;
  logic [BRAM_ADDR_BITS-1:0] rev_rx_bram_addr; 
  logic [7:0]             rev_rx_wr_data;
  logic [BUF_ID_BITS-1:0] rev_rx_buf_id;
  logic [BUF_ADDR_BITS-1:0] rev_rx_buf_addr;
  assign rev_rx_bram_addr = {rev_rx_buf_id, rev_rx_buf_addr};

  logic                   rev_tx_rd_en;
  logic [BRAM_ADDR_BITS-1:0] rev_tx_bram_addr;
  logic [7:0]             rev_tx_rd_data;
  logic [BUF_ID_BITS-1:0] rev_tx_buf_id;
  logic [BUF_ADDR_BITS-1:0] rev_tx_buf_addr;
  assign rev_tx_bram_addr = {rev_tx_buf_id, rev_tx_buf_addr};

  // ------------------------------------------------------------------------
  // Reverse Path Components
  // ------------------------------------------------------------------------

  async_init_fifo #(
      .DATA_WIDTH(BUF_ID_BITS),
      .FIFO_DEPTH(FIFO_DEPTH),
      .INIT_COUNT(NUM_BUFFERS_PER_CPU)
  ) rev_free_list_fifo (
      .rst          (rst),
      
      .push_clk     (eth1_clk),
      .i_push_data  (rev_free_buf_push_data),
      .i_push_valid (rev_free_buf_push_valid),
      .o_push_ready (rev_free_buf_push_ready),

      .pop_clk      (eth2_clk),
      .o_pop_data   (rev_free_buf_pop_data),
      .o_pop_valid  (rev_free_buf_pop_valid),
      .i_pop_ready  (rev_free_buf_pop_ready)
  );

  async_fifo #(
      .DATA_WIDTH($bits(packet_desc_t)),
      .FIFO_DEPTH(FIFO_DEPTH)
  ) rev_work_fifo (
      .rst          (rst),

      .push_clk     (eth2_clk),
      .i_push_data  (rev_work_push_data),
      .i_push_valid (rev_work_push_valid),
      .o_push_ready (rev_work_push_ready),

      .pop_clk      (eth1_clk),
      .o_pop_data   (rev_work_pop_data),
      .o_pop_valid  (rev_work_pop_valid),
      .i_pop_ready  (rev_work_pop_ready)
  );

  xilinx_true_dual_port_read_first_2_clock_ram #(
      .RAM_WIDTH(BRAM_WIDTH),
      .RAM_DEPTH(BRAM_DEPTH)
  ) rev_packet_bram (
      .clka   (eth2_clk),
      .addra  (rev_rx_bram_addr),
      .dina   (rev_rx_wr_data),
      .wea    (rev_rx_wr_en),
      .ena    (1'b1),
      .regcea (1'b1),
      .rsta   (rst),
      .douta  (), 

      .clkb   (eth1_clk),
      .addrb  (rev_tx_bram_addr),
      .dinb   (8'h0),
      .web    (1'b0),
      .enb    (rev_tx_rd_en), 
      .regceb (1'b1),
      .rstb   (rst),
      .doutb  (rev_tx_rd_data)
  );

  eth_rx eth2_rx_inst (
      .clk(eth2_clk),
      .rst(rst),

      .eth_crsdv(eth2_crsdv),
      .eth_rxd  (eth2_rxd),

      .i_free_buf_pop_cpu_id (0), 
      .i_free_buf_pop_data   (rev_free_buf_pop_data),
      .i_free_buf_pop_valid  (rev_free_buf_pop_valid),
      .o_free_buf_pop_ready  (rev_free_buf_pop_ready),

      .o_bpf_work_push_cpu_id(), 
      .o_bpf_work_push_data  (rev_work_push_data),
      .o_bpf_work_push_valid (rev_work_push_valid),
      .i_bpf_work_push_ready (rev_work_push_ready),

      .o_wren   (rev_rx_wr_en),
      .o_cpu_id (),
      .o_buf_id (rev_rx_buf_id),
      .o_wr_addr(rev_rx_buf_addr),
      .o_wr_data(rev_rx_wr_data),

      .o_byte_active        (),
      .o_pkt_received_pulse (),
      .o_pkt_sent_pulse     ()
  );

  eth_tx eth1_tx_inst (
      .clk(eth1_clk),
      .rst(rst),
      .eth_txen(eth1_txen),
      .eth_txd (eth1_txd),

      .i_tx_work_pop_cpu_id (0),
      .i_tx_work_pop_data   (rev_work_pop_data),
      .i_tx_work_pop_valid  (rev_work_pop_valid),
      .o_tx_work_pop_ready  (rev_work_pop_ready),

      .o_free_buf_push_cpu_id(),
      .o_free_buf_push_data  (rev_free_buf_push_data),
      .o_free_buf_push_valid (rev_free_buf_push_valid),
      .i_free_buf_push_ready (rev_free_buf_push_ready),

      .o_rd_en  (rev_tx_rd_en),
      .o_cpu_id (), 
      .o_buf_id (rev_tx_buf_id),
      .o_rd_addr(rev_tx_buf_addr),
      .i_rd_data(rev_tx_rd_data),

      .o_byte_active        (),
      .o_pkt_received_pulse (),
      .o_pkt_sent_pulse     ()
  );

endmodule
`default_nettype wire
