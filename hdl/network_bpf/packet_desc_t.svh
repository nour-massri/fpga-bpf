`ifndef PACKET_DEFS_SVH
`define PACKET_DEFS_SVH

// specific widths for the packet descriptor
`define PKT_BUF_ID_BITS 4
`define PKT_BUF_ADDR_BITS 10

typedef struct packed {
  logic [`PKT_BUF_ID_BITS-1:0]   id;     // Which buffer to use
  logic [`PKT_BUF_ADDR_BITS-1:0] len;    // Length of the packet
  logic                          valid;  // 1=valid frame, 0=invalid/drop
} packet_desc_t;

`endif
