"""
Generate synthetic Ethernet frames and write raw frame bytes to a file
(one byte per line, blank line between frames). Optionally write a pcap.
No packets are transmitted on the network.
"""
from scapy.all import Ether, IP, TCP, UDP, ICMP, Raw
from scapy.utils import PcapWriter
import argparse, random, time, os, binascii, ipaddress

def random_mac():
    return "02:%02x:%02x:%02x:%02x:%02x" % tuple(random.randint(0,255) for _ in range(5))

def random_private_ip():
    ranges = [
        ("10.0.0.0","10.255.255.255"),
        ("192.168.0.0","192.168.255.255"),
        ("172.16.0.0","172.31.255.255"),
        ("127.0.0.1","127.0.0.1"),
    ]
    lo, hi = random.choice(ranges)
    import ipaddress
    lo_i = int(ipaddress.IPv4Address(lo)); hi_i = int(ipaddress.IPv4Address(hi))
    return str(ipaddress.IPv4Address(random.randint(lo_i, hi_i)))

def random_payload(max_len=256):
    return os.urandom(random.randint(8, max_len))

def build_l3_packet(proto, dst_ip, sport=None, dport=None):
    if sport is None:
        sport = random.randint(1024, 65535)
    if dport is None:
        dport = random.randint(1, 65535)
    
    if (not (sport > 0 and sport <= 655535)):
        assert False
    if (not (dport > 0 and dport <= 655535)):
        assert False
    
    payload = Raw(random_payload(128))
    if proto == "tcp":
        return IP(dst=dst_ip)/TCP(sport=sport, dport=dport, flags="S")/payload
    if proto == "udp":
        return IP(dst=dst_ip)/UDP(sport=sport, dport=dport)/payload
    return IP(dst=dst_ip)/ICMP()/payload

def build_ether_frame(proto, dst_ip, src_mac=None, dst_mac=None, sport=None, dport=None):
    src_mac = src_mac or random_mac()
    dst_mac = dst_mac or random_mac()
    l3 = build_l3_packet(proto, dst_ip, sport, dport)
    return Ether(src=src_mac, dst=dst_mac)/l3

def hex_lines_from_bytes(bts, include_preamble=False):
    lines = []
    if include_preamble:
        pre = bytes.fromhex("55555555555555d5")
        bts = pre + bts
    for b in bts:
        lines.append(f"{b:02x}")
    return lines

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--count", type=int, default=1, help="number of frames")
    p.add_argument("--proto", choices=["tcp","udp","icmp","mixed"], default="mixed")
    p.add_argument("--target-ip", type=str, default=None, help="target IP (default: random private)")
    p.add_argument("--source-port", type=int, default=None, help="source port (default: random private)")
    p.add_argument("--target-port", type=int, default=None, help="target port (default: random private)")
    p.add_argument("--out-bytes", type=str, default="packets_bytes.txt", help="file with one byte per line, blank line between frames")
    p.add_argument("--out-pcap", type=str, default=None, help="optional pcap output")
    p.add_argument("--include-preamble", action="store_true", help="prepend Ethernet preamble+SFD (55..D5) to each frame")
    args = p.parse_args()

    os.makedirs(os.path.dirname(args.out_bytes) or ".", exist_ok=True)

    pcap_writer = PcapWriter(args.out_pcap, sync=True) if args.out_pcap else None
    out_fh = open(args.out_bytes, "w")

    try:
        for i in range(args.count):
            dst_ip = args.target_ip or random_private_ip()
            dst_port = args.target_port or None
            src_port = args.source_port or None

            proto = args.proto
            if proto == "mixed":
                proto = random.choice(["tcp","udp","icmp"])
            frame = build_ether_frame(proto, dst_ip, sport=src_port, dport=dst_port)
            raw = bytes(frame)   # raw ethernet frame (no preamble, no FCS)
            if pcap_writer:
                pcap_writer.write(frame)
            # write bytes: one hex byte per line, blank line between frames
            if args.include_preamble:
                raw = bytes.fromhex("55555555555555d5") + raw
            for b in raw:
                out_fh.write(f"{b:02x}\n")
            out_fh.write("\n")
    finally:
        if pcap_writer:
            pcap_writer.close()
        out_fh.close()

if __name__ == "__main__":
    main()