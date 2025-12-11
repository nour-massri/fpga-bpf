#!/usr/bin/env python3
"""
Robust FPGA Stress Sender (Multi-Protocol Support)
--------------------------------------------------
1. Generates packets (UDP, TCP, or ICMP) using Scapy.
2. Saves them to a temp PCAP file.
3. Uses 'tcpreplay' (with --intf1) to transmit them at a precise rate.

Usage:
    sudo ./robust_sender.py [count] [size] [mbps] [protocol]
"""

import sys
import os
import subprocess
import tempfile
from scapy.all import Ether, IP, UDP, TCP, ICMP, wrpcap

# --- Configuration ---
IFACE = "en7"
DST_MAC = "5a:65:7b:63:ba:d3"
SRC_MAC = "5a:65:7b:63:ba:d3" 
SRC_IP = "192.168.1.100"
DST_IP_BASE = "10"
SRC_PORT = 12345
DST_PORT = 53

# Defaults
DEFAULT_COUNT = 50000
DEFAULT_PAYLOAD = 1472
DEFAULT_MBPS = 100
DEFAULT_PROTO = "udp"

def check_tcpreplay():
    """Checks if tcpreplay is installed."""
    try:
        subprocess.run(["tcpreplay", "-V"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("Error: 'tcpreplay' is not found!")
        print("Please install it (macOS: 'brew install tcpreplay', Linux: 'apt install tcpreplay')")
        sys.exit(1)

def generate_pcap(count, payload_size, pcap_path, protocol="udp"):
    """Generates packets and writes them to a pcap file."""
    print(f"[1/3] Generating {count} {protocol.upper()} packets...")
    
    packets = []
    # Pre-calculate padding
    padding = bytes([0xAA] * (payload_size - 8))
    
    for i in range(count):
        # Encode packet number in destination IP (10.X.X.X)
        octet2 = (i >> 16) & 0xFF
        octet3 = (i >> 8) & 0xFF
        octet4 = i & 0xFF
        dst_ip = f"{DST_IP_BASE}.{octet2}.{octet3}.{octet4}"

        # Counter in payload (First 8 bytes)
        counter_bytes = i.to_bytes(8, byteorder='big')
        full_payload = counter_bytes + padding
        
        # Base L2/L3 Headers
        eth_ip = Ether(dst=DST_MAC, src=SRC_MAC) / IP(src=SRC_IP, dst=dst_ip)

        # L4 Header Selection
        if protocol == "udp":
            pkt = eth_ip / UDP(sport=SRC_PORT, dport=DST_PORT) / full_payload
        
        elif protocol == "tcp":
            # using PA (Push/Ack) flags to simulate data transfer
            pkt = eth_ip / TCP(sport=SRC_PORT, dport=DST_PORT, flags="PA") / full_payload
            
        elif protocol == "icmp":
            # Type 8 is Echo Request (Ping)
            pkt = eth_ip / ICMP(type=8, code=0) / full_payload
            
        else:
            print(f"Error: Unknown protocol {protocol}")
            sys.exit(1)
        
        packets.append(pkt)

        if i % 10000 == 0 and i > 0:
            print(f"      ... generated {i} packets")

    print(f"[2/3] Writing to temporary file: {pcap_path} ...")
    wrpcap(pcap_path, packets)
    print("      Write complete.")

def run_tcpreplay(iface, mbps, pcap_path):
    """Executes tcpreplay to send the traffic."""
    print(f"[3/3] Starting Transmission via tcpreplay...")
    print(f"      Target: {mbps} Mbps on {iface}")
    print("-" * 60)
    
    cmd = [
        "sudo", "tcpreplay",
        "--intf1=" + iface,
        "--mbps=" + str(mbps),
        pcap_path
    ]
    
    try:
        subprocess.run(cmd, check=True)
    except KeyboardInterrupt:
        print("\nStopping transmission...")
    except subprocess.CalledProcessError as e:
        print(f"\nError running tcpreplay: {e}")

def main():
    # Argument Parsing
    count = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_COUNT
    payload_size = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_PAYLOAD
    target_mbps = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_MBPS
    protocol = sys.argv[4].lower() if len(sys.argv) > 4 else DEFAULT_PROTO

    # Validation
    valid_protos = ["udp", "tcp", "icmp"]
    if protocol not in valid_protos:
        print(f"Error: Protocol must be one of {valid_protos}")
        sys.exit(1)
        
    if payload_size > 1472:
        payload_size = 1472
        print("Warning: Payload capped at 1472 bytes (MTU limit)")

    check_tcpreplay()

    # Create a temporary file for the pcap
    fd, temp_path = tempfile.mkstemp(suffix=".pcap")
    os.close(fd)

    try:
        generate_pcap(count, payload_size, temp_path, protocol)
        run_tcpreplay(IFACE, target_mbps, temp_path)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
            print("-" * 60)
            print("Temporary pcap file cleaned up.")

if __name__ == "__main__":
    main()