import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
test_file = os.path.basename(__file__).replace(".py","")


def bytes_to_2bit_chunks(byte_val):
    """Return list of four 2-bit chunks (MSB-first) for a byte."""
    return [ (byte_val >> 6) & 0x3,
             (byte_val >> 4) & 0x3,
             (byte_val >> 2) & 0x3,
             byte_val & 0x3 ]


@cocotb.test()
async def parser_basic_ipv4_packet(dut):
    """Drive a simple Ethernet frame containing an IPv4 packet and check parsed src_ip.

    This test drives eth_crsdv (data-valid) and eth_rxd (2-bit MII-style nibbles)
    one 2-bit chunk per clock. It sends a preamble + SFD, Ethernet header with
    dest/src MACs and ethertype 0x0800, then a minimal IPv4 header whose source
    IP we assert the DUT will extract and present on src_ip when ip_valid rises.
    """

    # start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # initial values
    dut.rst.value = 1
    dut.eth_crsdv.value = 0
    dut.eth_rxd.value = 0

    # hold reset for a few cycles
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst.value = 0

    # Compose a frame
    # Preamble: 7 bytes of 0x55, SFD 0xD5
    preamble = [0x55] * 7 + [0xD5]

    # Example MACs
    dst_mac = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    src_mac = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]

    # Ethertype: IPv4 0x0800
    ethertype = [0x08, 0x00]

    # Minimal IPv4 header (20 bytes) - many fields set to reasonable values
    # We only care about source IP which we set here
    src_ip_bytes = [192, 168,  1,  42]  # 192.168.1.42
    # Build a minimal IPv4 header (version/IHL, DSCP/ECN, total length, id, flags/frag,
    # ttl, protocol, header checksum, src ip, dst ip)
    ip_header = [
        0x45, 0x00,             # Version/IHL, DSCP
        0x00, 0x14,             # Total Length = 20 (header only)
        0x00, 0x00,             # Identification
        0x00, 0x00,             # Flags/Fragment
        64, 6,                  # TTL=64, Protocol=6 (TCP)
        0x00, 0x00,             # Header checksum (ignored by parser)
    ]
    # Assemble full IP payload header (we'll set dst ip to 8.8.8.8)
    dst_ip_bytes = [8, 8, 8, 8]
    ip_header += src_ip_bytes + dst_ip_bytes

    # No payload beyond header for this simple test

    # Full frame bytes after preamble/SFD
    frame_bytes = dst_mac + src_mac + ethertype + ip_header

    # Send preamble+SFD and then frame while asserting eth_crsdv.
    # Bring eth_crsdv high one cycle before first data chunk so rising edge is seen by DUT.
    await RisingEdge(dut.clk)
    dut.eth_crsdv.value = 1

    # send preamble+SFD
    for b in preamble:
        for chunk in bytes_to_2bit_chunks(b):
            dut.eth_rxd.value = chunk
            await RisingEdge(dut.clk)

    # send Ethernet frame (eth header + ethertype + ip header)
    for b in frame_bytes:
        for chunk in bytes_to_2bit_chunks(b):
            dut.eth_rxd.value = chunk
            await RisingEdge(dut.clk)

    # Deassert eth_crsdv to indicate end of frame
    dut.eth_crsdv.value = 0
    dut.eth_rxd.value = 0

    # Wait for ip_valid (with timeout)
    seen = False
    for _ in range(1000):
        await RisingEdge(dut.clk)
        try:
            if int(dut.ip_valid.value) == 1:
                seen = True
                break
        except Exception:
            # unknown value (X); keep waiting
            pass

    assert seen, "ip_valid never asserted by parser"

    # Read src_ip and compare
    dut_src_ip = int(dut.src_ip.value)
    expected = (src_ip_bytes[0] << 24) | (src_ip_bytes[1] << 16) | (src_ip_bytes[2] << 8) | src_ip_bytes[3]
    assert dut_src_ip == expected, f"src_ip mismatch: got 0x{dut_src_ip:08x}, expected 0x{expected:08x}"

    # let a couple cycles run
    for _ in range(5):
        await RisingEdge(dut.clk)

def parser_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "parser.sv"]
    build_test_args = ["-Wall"]
    parameters = {} #!!!change these to do different versions
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "parser"
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    parser_runner()