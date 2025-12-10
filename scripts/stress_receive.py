#!/usr/bin/env python3
"""
High-accuracy stress test receiver using tcpdump for packet capture.
More reliable than scapy sniff() for high packet rates.

Usage:
    python3 stress_receive_tcpdump.py [count] [payload_size] [timeout]

    count: Number of packets to expect (default: 50000)
    payload_size: Expected payload size (default: 1472)
    timeout: Capture timeout in seconds (default: 60)
"""
import sys
import time
import subprocess
import tempfile
import os
from scapy.all import rdpcap, IP, UDP

iface = "en7"

# Parse command line arguments
expected_count = 50000
expected_payload_size = 1500 
timeout = 60

if len(sys.argv) > 1:
    expected_count = int(sys.argv[1])
if len(sys.argv) > 2:
    expected_payload_size = int(sys.argv[2])
if len(sys.argv) > 3:
    timeout = int(sys.argv[3])

print(f"High-accuracy stress test receiver")
print(f"Interface: {iface}")
print(f"Expected packets: {expected_count}")
print(f"Expected payload size: {expected_payload_size} bytes")
print(f"Timeout: {timeout}s")
print(f"Filter: UDP packets to 10.0.0.0/8 port 53")
print("=" * 60)

pcap_file = tempfile.NamedTemporaryFile(mode='w+b', suffix='.pcap', delete=False)
pcap_filename = pcap_file.name
pcap_file.close()

print(f"\nStarting tcpdump capture...")
print(f"Temp file: {pcap_filename}")

tcpdump_cmd = [
    'tcpdump',
    '-i', iface,
    '-w', pcap_filename,
    '-c', str(expected_count),  # Stop after expected count
    'udp', 'and', 'dst', 'net', '10.0.0.0/8', 'and', 'dst', 'port', '53'
]

try:
    print(f"Running: {' '.join(tcpdump_cmd)}")
    print(f"\nWaiting for packets (max {timeout}s)...")
    print("Press Ctrl+C to stop early\n")

    start_time = time.time()
    proc = subprocess.Popen(
        tcpdump_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        print("\nTimeout reached, stopping capture...")
        proc.terminate()
        proc.wait()

    end_time = time.time()
    elapsed = end_time - start_time

    print(f"\nCapture completed in {elapsed:.2f}s")

except KeyboardInterrupt:
    print("\n\nCapture interrupted by user")
    proc.terminate()
    proc.wait()
    end_time = time.time()
    elapsed = end_time - start_time

print("\n" + "=" * 60)
print("ANALYZING PACKETS")
print("=" * 60)

# Check if pcap file exists and has data
if not os.path.exists(pcap_filename) or os.path.getsize(pcap_filename) == 0:
    print("No packets captured!")
    os.unlink(pcap_filename)
    sys.exit(1)

print(f"Reading pcap file...")

packets = rdpcap(pcap_filename)
packet_count = len(packets)

print(f"Total packets captured: {packet_count}")
print(f"Capture rate: {packet_count/elapsed:.2f} packets/sec")

received_counters = []
received_via_ip = []
payload_size_errors = 0
ip_counter_mismatches = 0
total_bytes = 0

print("\nAnalyzing packet contents...")
for i, pkt in enumerate(packets):
    if i % 10000 == 0 and i > 0:
        print(f"  Analyzed {i}/{packet_count} packets...")

    total_bytes += len(pkt)

    counter_from_ip = None
    if pkt.haslayer(IP):
        dst_ip = pkt[IP].dst
        if dst_ip.startswith("10."):
            ip_parts = dst_ip.split(".")
            if len(ip_parts) == 4:
                octet2 = int(ip_parts[1])
                octet3 = int(ip_parts[2])
                octet4 = int(ip_parts[3])
                counter_from_ip = (octet2 << 16) | (octet3 << 8) | octet4
                received_via_ip.append(counter_from_ip)

    if pkt.haslayer(UDP):
        payload_bytes = bytes(pkt[UDP].payload)
        actual_payload_size = len(payload_bytes)

        if actual_payload_size != expected_payload_size:
            payload_size_errors += 1

        if actual_payload_size >= 8:
            counter = int.from_bytes(payload_bytes[:8], byteorder='big')
            received_counters.append(counter)

            if counter_from_ip is not None and counter_from_ip != counter:
                ip_counter_mismatches += 1

print(f"Analysis complete!\n")

print("=" * 60)
print("STATISTICS")
print("=" * 60)
print(f"\nPackets captured: {packet_count}")
print(f"Time elapsed: {elapsed:.4f} seconds")
print(f"Average rate: {packet_count/elapsed:.2f} packets/sec")
print(f"Total data received: {total_bytes / 1_000_000:.2f} MB")
print(f"Data rate: {(total_bytes * 8) / elapsed / 1_000_000:.2f} Mbps")
if packet_count > 0:
    print(f"Average frame size: {total_bytes / packet_count:.1f} bytes")

received_counters.sort()

expected_set = set(range(expected_count))
received_set = set(received_counters)
missing = expected_set - received_set
duplicates = [c for c in received_counters if received_counters.count(c) > 1]

print(f"\n--- Packet Loss Analysis ---")
print(f"Expected packets: {expected_count}")
print(f"Received packets: {len(received_set)}")
print(f"Lost packets: {len(missing)}")
if len(missing) > 0:
    loss_rate = (len(missing) / expected_count) * 100
    print(f"Loss rate: {loss_rate:.2f}%")
    if len(missing) <= 20:
        print(f"Missing counters: {sorted(missing)}")
    else:
        print(f"First 20 missing: {sorted(missing)[:20]}")
else:
    print("No packet loss detected!")

print(f"\n--- Duplicate Analysis ---")
if duplicates:
    unique_duplicates = set(duplicates)
    print(f"Duplicate packets: {len(duplicates)}")
    if len(unique_duplicates) <= 20:
        print(f"Duplicate counters: {sorted(unique_duplicates)}")
else:
    print("No duplicates detected!")

print(f"\n--- Order Analysis ---")
if received_counters == sorted(received_counters):
    print("All packets received in order!")
else:
    out_of_order = 0
    for i in range(1, len(received_counters)):
        if received_counters[i] < received_counters[i-1]:
            out_of_order += 1
    print(f"Out-of-order packets: {out_of_order}")

print(f"\n--- Counter Range ---")
if received_counters:
    print(f"Minimum counter: {min(received_counters)}")
    print(f"Maximum counter: {max(received_counters)}")
    print(f"Expected range: 0 to {expected_count - 1}")

print(f"\n--- Payload Validation ---")
print(f"Expected payload size: {expected_payload_size} bytes")
if payload_size_errors > 0:
    print(f"Payload size mismatches: {payload_size_errors}")
else:
    print("All payloads matched expected size!")

print(f"\n--- IP Encoding Validation ---")
print(f"Counters decoded from IP addresses: {len(received_via_ip)}")
if ip_counter_mismatches > 0:
    print(f"IP/Payload counter mismatches: {ip_counter_mismatches}")
else:
    print("All IP-encoded counters matched payload counters!")

print("\n" + "=" * 60)

os.unlink(pcap_filename)
print(f"\nCleaned up temp file: {pcap_filename}")
