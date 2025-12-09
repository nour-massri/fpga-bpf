import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
test_file = os.path.basename(__file__).replace(".py","")


def load_hex_mem(path):
    data = []
    p = Path(path)
    if not p.exists():
        return data
    for line in p.read_text().splitlines():
        s = line.strip().split()[0] if line.strip() else ""
        if not s:
            continue
        data.append(int(s, 16))
    return data

@cocotb.test()
async def run_bpf_cpu_tcp(dut):
    """Basic cocotb test for bpf_cpu: drives clock/reset, provides BRAM model, starts CPU and waits for done."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.i_start.value = 0
    dut.i_packet_len.value = 0
    dut.i_ram_data.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    mem_path = Path(__file__).resolve().parent  / "tcp_bytes.txt"
    pkt_mem = load_hex_mem(str(mem_path))
    if not pkt_mem:
        pkt_mem = [i & 0xFF for i in range(1024)]
        dut._log.warning("tcp_bytes.txt not found; using synthetic packet data")

    async def bram_model():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.o_ram_rd_en.value) == 1:
                addr = int(dut.o_ram_addr.value)
                data = pkt_mem[addr] if addr < len(pkt_mem) else 0
                await RisingEdge(dut.clk)     
                dut.i_ram_data.value = data

    cocotb.start_soon(bram_model())

    dut.i_packet_len.value = 12
    dut.i_start.value = 1
    await RisingEdge(dut.clk)
    dut.i_start.value = 0

    # wait for done with timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if dut.o_done.value == 1:
            assert dut.o_pass_packet.value == 0
            break
    else:
        raise cocotb.result.TestFailure("Timeout waiting for o_done")

    dut._log.info(f"BPF finished, o_pass_packet={int(dut.o_pass_packet.value)}")
    await Timer(100, units="ns")


@cocotb.test()
async def run_bpf_cpu_udp(dut):
    """Basic cocotb test for bpf_cpu: drives clock/reset, provides BRAM model, starts CPU and waits for done."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.i_start.value = 0
    dut.i_packet_len.value = 0
    dut.i_ram_data.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    mem_path = Path(__file__).resolve().parent  / "udp_bytes.txt"
    pkt_mem = load_hex_mem(str(mem_path))
    if not pkt_mem:
        pkt_mem = [i & 0xFF for i in range(1024)]
        dut._log.warning("udp_bytes.txt not found; using synthetic packet data")

    async def bram_model():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.o_ram_rd_en.value) == 1:
                addr = int(dut.o_ram_addr.value)
                data = pkt_mem[addr] if addr < len(pkt_mem) else 0
                await RisingEdge(dut.clk)     
                dut.i_ram_data.value = data

    cocotb.start_soon(bram_model())

    dut.i_packet_len.value = 12
    dut.i_start.value = 1
    await RisingEdge(dut.clk)
    dut.i_start.value = 0

    # wait for done with timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if dut.o_done.value == 1:
            assert dut.o_pass_packet.value == 0
            break
    else:
        raise cocotb.result.TestFailure("Timeout waiting for o_done")

    dut._log.info(f"BPF finished, o_pass_packet={int(dut.o_pass_packet.value)}")
    await Timer(100, units="ns")


@cocotb.test()
async def run_bpf_cpu_icmp(dut):
    """Basic cocotb test for bpf_cpu: drives clock/reset, provides BRAM model, starts CPU and waits for done."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.i_start.value = 0
    dut.i_packet_len.value = 0
    dut.i_ram_data.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    mem_path = Path(__file__).resolve().parent  / "icmp_bytes.txt"
    pkt_mem = load_hex_mem(str(mem_path))
    if not pkt_mem:
        pkt_mem = [i & 0xFF for i in range(1024)]
        dut._log.warning("icmp_bytes.txt not found; using synthetic packet data")

    async def bram_model():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.o_ram_rd_en.value) == 1:
                addr = int(dut.o_ram_addr.value)
                data = pkt_mem[addr] if addr < len(pkt_mem) else 0
                await RisingEdge(dut.clk)     
                dut.i_ram_data.value = data

    cocotb.start_soon(bram_model())

    dut.i_packet_len.value = 12
    dut.i_start.value = 1
    await RisingEdge(dut.clk)
    dut.i_start.value = 0

    # wait for done with timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if dut.o_done.value == 1:
            assert dut.o_pass_packet.value == 0
            break
    else:
        raise cocotb.result.TestFailure("Timeout waiting for o_done")

    dut._log.info(f"BPF finished, o_pass_packet={int(dut.o_pass_packet.value)}")
    await Timer(100, units="ns")


@cocotb.test()
async def run_bpf_cpu_port53(dut):
    """Basic cocotb test for bpf_cpu: drives clock/reset, provides BRAM model, starts CPU and waits for done."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.i_start.value = 0
    dut.i_packet_len.value = 0
    dut.i_ram_data.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    mem_path = Path(__file__).resolve().parent  / "specific_port_bytes.txt"
    pkt_mem = load_hex_mem(str(mem_path))
    if not pkt_mem:
        pkt_mem = [i & 0xFF for i in range(1024)]
        dut._log.warning("specific_port_bytes.txt not found; using synthetic packet data")

    async def bram_model():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.o_ram_rd_en.value) == 1:
                addr = int(dut.o_ram_addr.value)
                data = pkt_mem[addr] if addr < len(pkt_mem) else 0
                await RisingEdge(dut.clk)     
                dut.i_ram_data.value = data

    cocotb.start_soon(bram_model())

    dut.i_packet_len.value = 100
    dut.i_start.value = 1
    await RisingEdge(dut.clk)
    dut.i_start.value = 0

    # wait for done with timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if dut.o_done.value == 1:
            assert dut.o_pass_packet.value == 1
            break
    else:
        raise cocotb.result.TestFailure("Timeout waiting for o_done")

    dut._log.info(f"BPF finished, o_pass_packet={int(dut.o_pass_packet.value)}")
    await Timer(100, units="ns")



@cocotb.test()
async def run_bpf_cpu_udp_deadbeef(dut):
    """Basic cocotb test for bpf_cpu: drives clock/reset, provides BRAM model, starts CPU and waits for done."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.i_start.value = 0
    dut.i_packet_len.value = 0
    dut.i_ram_data.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    mem_path = Path(__file__).resolve().parent  / "ttl_less_than_ten_udp.txt"
    pkt_mem = load_hex_mem(str(mem_path))
    if not pkt_mem:
        pkt_mem = [i & 0xFF for i in range(1024)]
        dut._log.warning("ttl_correct_port_correct.txt not found; using synthetic packet data")

    async def bram_model():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.o_ram_rd_en.value) == 1:
                addr = int(dut.o_ram_addr.value)
                data = pkt_mem[addr] if addr < len(pkt_mem) else 0
                await RisingEdge(dut.clk)     
                dut.i_ram_data.value = data

    cocotb.start_soon(bram_model())

    dut.i_packet_len.value = 100
    dut.i_start.value = 1
    await RisingEdge(dut.clk)
    dut.i_start.value = 0

    # wait for done with timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if dut.o_done.value == 1:
            assert dut.o_pass_packet.value == 1
            break
    else:
        raise cocotb.result.TestFailure("Timeout waiting for o_done")

    dut._log.info(f"BPF finished, o_pass_packet={int(dut.o_pass_packet.value)}")
    await Timer(100, units="ns")




@cocotb.test()
async def run_bpf_cpu_ultimate_test(dut):
    """Basic cocotb test for bpf_cpu: drives clock/reset, provides BRAM model, starts CPU and waits for done."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.i_start.value = 0
    dut.i_packet_len.value = 0
    dut.i_ram_data.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    mem_path = Path(__file__).resolve().parent  / "ultimate_test_pass_clause_1.txt"
    pkt_mem = load_hex_mem(str(mem_path))
    if not pkt_mem:
        pkt_mem = [i & 0xFF for i in range(1024)]
        dut._log.warning("ultimate_test_pass_clause_1.txt not found; using synthetic packet data")

    async def bram_model():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.o_ram_rd_en.value) == 1:
                addr = int(dut.o_ram_addr.value)
                data = pkt_mem[addr] if addr < len(pkt_mem) else 0
                await RisingEdge(dut.clk)     
                dut.i_ram_data.value = data

    cocotb.start_soon(bram_model())

    dut.i_packet_len.value = 100
    dut.i_start.value = 1
    await RisingEdge(dut.clk)
    dut.i_start.value = 0

    # wait for done with timeout
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if dut.o_done.value == 1:
            assert dut.o_pass_packet.value == 1
            break
    else:
        raise cocotb.result.TestFailure("Timeout waiting for o_done")

    dut._log.info(f"BPF finished, o_pass_packet={int(dut.o_pass_packet.value)}")
    await Timer(100, units="ns")



def is_runner():
    """BFP CPU Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "network_bpf" / "network_bpf_config_pkg.sv"]
    sources += [proj_path / "hdl" / "network_bpf" / "bpf_cpu.sv"]
    sources += [proj_path / "hdl" / "utils" / "memories" / "xilinx_single_port_ram_read_first.v"]
    sources += [proj_path / "hdl" / "utils" / "memories" / "xilinx_true_dual_port_read_first_1_clock_ram.v"]

    build_test_args = ["-Wall"]
    parameters = {'PC_WIDTH': 8, "ROM_LATENCY":2}
    hdl_toplevel = "bpf_cpu"
    sys.path.append(str(proj_path / "sim"))
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
    is_runner()
    # mem_path = Path(__file__).resolve().parent  / "packets_bytes.txt"

    # print(str(mem_path))

    # data =  load_hex_mem(str(mem_path))
    # print(data)
