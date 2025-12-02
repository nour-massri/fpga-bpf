import sys
from scapy.all import Ether, IP, UDP, sendp, hexdump

iface = "en10"

# --- Layer 2 (Ethernet) ---
dst_mac = "5a:65:7b:63:ba:d3" 
src_mac = "5a:65:7b:63:ba:d3"

# --- Layer 3 (IP) ---
src_ip = "192.168.1.100"
dst_ip = "8.8.8.8"

# --- Layer 4 (UDP) ---
src_port = 12345
dst_port = 53

count = 10
if len(sys.argv) > 1:
    count = int(sys.argv[1])

# Send packets with incrementing source IP addresses
for i in range(count):
    current_src_ip = f"192.168.1.{100 + i}"

    eth = Ether(dst=dst_mac, src=src_mac, type=0x0800)
    ip = IP(src=current_src_ip, dst=dst_ip, proto=17) # proto=17 for UDP
    udp = UDP(sport=src_port, dport=dst_port)
    payload = f"packet {i}".encode()  # Label each packet
    pkt = eth / ip / udp / payload

    print(f"Sending packet {i}: src_ip={current_src_ip}, Frame size: {len(bytes(pkt))}")

    sendp(pkt, iface=iface, count=1, inter=0.1, verbose=False)