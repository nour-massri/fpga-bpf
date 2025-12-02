`timescale 1ns / 1ps `default_nettype none

// ============================================================================
// Network_BPF Configuration Package
// ============================================================================

package network_bpf_config_pkg;

  // ------------------------------------------------------------------------
  // Configuration Parameters
  // ------------------------------------------------------------------------
  localparam int NUM_CPUS = 4;
  localparam int NUM_BUFFERS_PER_CPU = 16;
  localparam int BUFFER_SIZE = 1024;

  // ------------------------------------------------------------------------
  // Derived Parameters 
  // ------------------------------------------------------------------------
  localparam int CPU_ID_BITS = $clog2(NUM_CPUS);
  localparam int BUF_ID_BITS = $clog2(NUM_BUFFERS_PER_CPU);
  localparam int BUF_ADDR_BITS = $clog2(BUFFER_SIZE);

  localparam int BRAM_ADDR_BITS = BUF_ID_BITS + BUF_ADDR_BITS;
  localparam int BRAM_DEPTH = NUM_BUFFERS_PER_CPU * BUFFER_SIZE;
  localparam int BRAM_WIDTH = 8;  // 1 byte
  localparam int FIFO_DEPTH = 2 * NUM_BUFFERS_PER_CPU;

  // ------------------------------------------------------------------------
  // Packet Descriptor Type
  // ------------------------------------------------------------------------
  typedef struct packed {
    logic [BUF_ID_BITS-1:0]   id;     // Which buffer to use
    logic [BUF_ADDR_BITS-1:0] len;    // Length of the packet
    logic                     valid;  // 1=valid frame, 0=invalid/drop
  } packet_desc_t;

endpackage

`default_nettype wire
