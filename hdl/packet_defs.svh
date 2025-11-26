`ifndef PACKET_DEFS_SVH
`define PACKET_DEFS_SVH

// specific widths for the packet descriptor
`define PKT_BUF_ID_BITS 2
`define PKT_BUF_ADDR_BITS 11

typedef struct packed {
  logic [`PKT_BUF_ID_BITS-1:0]   id;     // Which buffer to use
  logic [`PKT_BUF_ADDR_BITS-1:0] len;    // Length of the packet
  logic                          valid;  // 1=valid frame, 0=invalid/drop
} packet_desc_t;

typedef struct packed {
  logic status;
  logic [31:0] src_ip;
  logic [31:0] dst_ip;
  logic [15:0] src_port;
  logic [15:0] dst_port;
} display_job_t;
`endif
