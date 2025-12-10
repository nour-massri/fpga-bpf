#!/usr/bin/env python3
"""
Optimized stress test sender for macOS using Scapy with L2Socket.

Usage:
    sudo python3 stress_send.py [count] [payload_size] [target_mbps]

    count: Number of packets to send (default: 50000)
    payload_size: Size of payload in bytes (default: 1472)
    target_mbps: Target data rate in Mbps (default: 50)
"""
import sys
import time
from scapy.all import Ether, IP, UDP, conf

iface = "en10"

# --- Layer 2 (Ethernet) ---
dst_mac = "5a:65:7b:63:ba:d3"
src_mac = "5a:65:7b:63:ba:d3"

# --- Layer 3 (IP) ---
src_ip = "192.168.1.100"
dst_ip_base = "10"

# --- Layer 4 (UDP) ---
src_port = 12345
dst_port = 53

# Parse command line arguments
count = 50000
payload_size = 1500 
target_mbps = 100

if len(sys.argv) > 1:
    count = int(sys.argv[1])
if len(sys.argv) > 2:
    payload_size = int(sys.argv[2])
if len(sys.argv) > 3:
    target_mbps = int(sys.argv[3])

# Validate payload size
MIN_PAYLOAD = 8
MAX_PAYLOAD = 1472

if payload_size < MIN_PAYLOAD:
    print(f"Error: payload_size must be at least {MIN_PAYLOAD} bytes")
    sys.exit(1)
if payload_size > MAX_PAYLOAD:
    print(f"Warning: Using max payload size {MAX_PAYLOAD} bytes")
    payload_size = MAX_PAYLOAD

print(f"Optimized macOS stress test: {count} packets")
print(f"Interface: {iface}")
print(f"Payload size: {payload_size} bytes")
print(f"Destination IP encoding: 10.A.B.C (24-bit)")
print("-" * 60)

print("Pre-building packets...")
build_start = time.time()

packets = []
for i in range(count):
    # Encode packet number in destination IP
    octet2 = (i >> 16) & 0xFF
    octet3 = (i >> 8) & 0xFF
    octet4 = i & 0xFF
    dst_ip = f"{dst_ip_base}.{octet2}.{octet3}.{octet4}"

    eth = Ether(dst=dst_mac, src=src_mac, type=0x0800)
    ip = IP(src=src_ip, dst=dst_ip, proto=17)
    udp = UDP(sport=src_port, dport=dst_port)

    counter_bytes = i.to_bytes(8, byteorder='big')
    padding = bytes([0xAA] * (payload_size - 8))
    payload = counter_bytes + padding

    pkt = eth / ip / udp / payload
    packets.append(bytes(pkt))

build_time = time.time() - build_start

frame_size = len(packets[0])
print(f"Frame size: {frame_size} bytes")
print(f"Build time: {build_time:.2f} seconds ({count/build_time:.0f} pkts/s)")
print(f"Total data: {(count * frame_size) / 1_000_000:.2f} MB")
print(f"Estimated bandwidth: {(count * frame_size * 8) / 1_000_000:.2f} Mb")
print()

try:
    print("Opening L2 socket...")
    socket = conf.L2socket(iface=iface)
except Exception as e:
    print(f"Error opening socket: {e}")
    print("Make sure to run with sudo!")
    sys.exit(1)

print(f"Starting optimized transmission...")
print(f"Note: Progress updates every 10k packets\n")

# Calculate delay to maintain target data rate based on frame size
target_bits_per_sec = target_mbps * 1_000_000
bits_per_packet = frame_size * 8
packets_per_sec = target_bits_per_sec / bits_per_packet
delay_per_packet = 1.0 / packets_per_sec

print(f"Target rate: {target_mbps} Mbps")
print(f"Delay per packet: {delay_per_packet*1000:.3f} ms ({packets_per_sec:.0f} pkt/s)\n")

start_time = time.time()
sent = 0

try:
    for i in range(count):
        packet_start = time.time()
        socket.send(packets[i])
        send_time = time.time() - packet_start
        sent += 1

        # Adjust delay to account for send time
        adjusted_delay = delay_per_packet - send_time
        if adjusted_delay > 0:
            time.sleep(adjusted_delay)

        # Print progress every 10000 packets
        if sent % 10000 == 0:
            elapsed = time.time() - start_time
            rate = sent / elapsed if elapsed > 0 else 0
            data_rate = (sent * frame_size * 8) / elapsed / 1_000_000 if elapsed > 0 else 0
            print(f"Sent {sent}/{count} packets ({rate:.0f} pkt/s, {data_rate:.1f} Mbps)")

except KeyboardInterrupt:
    print("\n\nInterrupted by user!")

end_time = time.time()
elapsed = end_time - start_time

socket.close()

print()
print("=" * 60)
print("TRANSMISSION COMPLETE")
print("=" * 60)
print(f"Packets sent: {sent}")
print(f"Time elapsed: {elapsed:.4f} seconds")
if elapsed > 0:
    print(f"Average rate: {sent/elapsed:.0f} packets/sec")
    print(f"Data rate: {(sent * frame_size * 8) / elapsed / 1_000_000:.2f} Mbps")
    print(f"Total data: {(sent * frame_size) / 1_000_000:.2f} MB")

    theoretical_max = 1000_000_000 / 8 / frame_size  # 1 Gbps
    efficiency = (sent/elapsed) / theoretical_max * 100 if theoretical_max > 0 else 0
    print(f"\nLine efficiency: {efficiency:.1f}% of 1 Gbps")
print("=" * 60)
