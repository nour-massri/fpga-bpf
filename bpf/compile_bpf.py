import subprocess
import sys
import re
import argparse
import os

def compile_bpf(expression, base_name="filter"):
    """
    Compiles a BPF expression using tcpdump and saves three files:
    1. .txt   - Human readable assembly
    2. .bin - Raw C-style machine code output
    3. .mem     - FPGA compatible hex format
    """
    
    mem_filename = f"{base_name}.mem"
    human_filename = f"{base_name}.txt"
    machine_filename = f"{base_name}.bin"

    base_cmd = ["tcpdump"]
    
    if sys.platform == "darwin":
        base_cmd.extend(["-i", "en0"])
        
    base_cmd.extend(["-y", "EN10MB"])

    print(f"--- Compiling BPF: '{expression}' ---")
    print(f"Command base: {' '.join(base_cmd)}")

    # ---------------------------------------------------------
    # 1. Generate Human Readable Assembly (tcpdump -d)
    # ---------------------------------------------------------
    try:
        human_readable = subprocess.check_output(
            base_cmd + ["-d", expression], 
            stderr=subprocess.STDOUT
        ).decode('utf-8')
        
        with open(human_filename, 'w') as f:
            f.write(human_readable)
        print(f"1. Human readable assembly saved to: {human_filename}")
        print(human_readable)
        
    except subprocess.CalledProcessError as e:
        print(f"Error running tcpdump (human): {e.output.decode('utf-8')}")
        print("Tip: Try running with 'sudo' if you have permission issues.")
        sys.exit(1)
    except FileNotFoundError:
        print("Error: 'tcpdump' not found. Please install it.")
        sys.exit(1)

    # ---------------------------------------------------------
    # 2. Generate Machine Code (tcpdump -dd)
    # ---------------------------------------------------------
    try:
        raw_c_output = subprocess.check_output(
            base_cmd + ["-dd", expression], 
            stderr=subprocess.STDOUT
        ).decode('utf-8')
        
        with open(machine_filename, 'w') as f:
            f.write(raw_c_output)
        print(f"2. Raw C-style machine code saved to: {machine_filename}")
        
    except subprocess.CalledProcessError as e:
        print(f"Error generating machine code: {e.output.decode('utf-8')}")
        sys.exit(1)

    # ---------------------------------------------------------
    # 3. Parse to .mem file
    # ---------------------------------------------------------
    # Input format expected: { 0x28, 0, 0, 0x0000000c },
    # Output format: 64-bit hex string [Opcode:16][JT:8][JF:8][K:32]
    
    lines = raw_c_output.strip().splitlines()
    mem_lines = []
    
    print(f"--- Parsing {len(lines)} instructions for .mem file ---")
    
    for i, line in enumerate(lines):
        clean_line = line.replace('{', '').replace('}', '').replace(',', '').strip()
        parts = clean_line.split()
        
        if len(parts) != 4:
            continue

        opcode = int(parts[0], 0)
        jt = int(parts[1], 0)
        jf = int(parts[2], 0)
        k = int(parts[3], 0)

        hex_str = f"{opcode:04X}{jt:02X}{jf:02X}{k:08X}"
        mem_lines.append(hex_str)

    try:
        with open(mem_filename, 'w') as f:
            for hex_line in mem_lines:
                f.write(hex_line + '\n')
        print(f"3. FPGA machine code saved to: {mem_filename}")
        print(f"--- Success ---")
    except IOError as e:
        print(f"Error writing .mem file: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Compile BPF expression to FPGA .mem, .bin, and .txt files')
    parser.add_argument('expression', help='The BPF expression (e.g. "ip and udp")')
    parser.add_argument('-o', '--output', default='filter', help='Base output filename (default: filter)')
    
    args = parser.parse_args()
    
    compile_bpf(args.expression, args.output)