import argparse
from scapy.all import Ether, IP, UDP, TCP, ICMP, sendp

iface = "en10"

# --- Layer 2 (Ethernet) ---
dst_mac = "5a:65:7b:63:ba:d3"
src_mac = "5a:65:7b:63:ba:d3"

# --- Layer 3 (IP) ---
src_ip = "192.168.1.100"
dst_ip = "8.8.8.8"

# --- Layer 4 (Transport) ---
src_port = 12345
dst_port = 53

# Parse command line arguments
parser = argparse.ArgumentParser(description='Send packets with different protocols')
parser.add_argument('count', type=int, nargs='?', default=10, help='Number of packets to send (default: 10)')
parser.add_argument('-p', '--protocol', type=str, default='udp', choices=['udp', 'tcp', 'icmp'],
                    help='Protocol to use: udp, tcp, or icmp (default: udp)')
parser.add_argument('--filter-match', action='store_true',
                    help='Generate packets that match the BPF filter (IPv4 UDP port 443, len >= 500)')
args = parser.parse_args()

count = args.count
protocol = args.protocol.lower()

# Override settings if filter-match mode is enabled
if args.filter_match:
    print("Filter-match mode: Generating packets that satisfy the BPF filter")
    print("  - IPv4 (EtherType 0x800)")
    print("  - UDP (protocol 17)")
    print("  - Destination port 443")
    print("  - Packet length >= 500 bytes")
    protocol = 'udp'
    dst_port = 443

# Send packets with incrementing source IP addresses
for i in range(count):
    current_src_ip = f"192.168.1.{100 + i}"

    eth = Ether(dst=dst_mac, src=src_mac, type=0x0800)

    if protocol == 'udp':
        ip = IP(src=current_src_ip, dst=dst_ip, proto=17)  # proto=17 for UDP
        transport = UDP(sport=src_port, dport=dst_port)

        # If filter-match mode, ensure packet is at least 500 bytes
        if args.filter_match:
            min_payload_size = 500 - 42
            payload = f"packet {i}".encode() + b'X' * (min_payload_size - len(f"packet {i}".encode()))
        else:
            payload = f"packet {i}".encode()

        pkt = eth / ip / transport / payload
    elif protocol == 'tcp':
        ip = IP(src=current_src_ip, dst=dst_ip, proto=6)  # proto=6 for TCP
        transport = TCP(sport=src_port, dport=dst_port, flags='S')  # SYN flag
        payload = f"packet {i}".encode()
        pkt = eth / ip / transport / payload
    elif protocol == 'icmp':
        ip = IP(src=current_src_ip, dst=dst_ip, proto=1)  # proto=1 for ICMP
        icmp = ICMP(type=8, code=0)  # Echo request
        payload = f"packet {i}".encode()
        pkt = eth / ip / icmp / payload

    print(f"Sending {protocol.upper()} packet {i}: src_ip={current_src_ip}, dst_port={dst_port}, Frame size: {len(bytes(pkt))}")

    sendp(pkt, iface=iface, count=1, inter=0.1, verbose=False)