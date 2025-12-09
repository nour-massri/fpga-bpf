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

def build_l3_packet(proto, dst_ip, sport=None, dport=None, payload_bytes=None, ttl=None):
    if sport is None:
        sport = random.randint(1024, 65535)
    if dport is None:
        dport = random.randint(1, 65535)

    # basic validation (ports must fit into 16 bits)
    assert 0 < sport <= 65535
    assert 0 < dport <= 65535

    # payload_bytes may be None (generate random) or bytes
    if payload_bytes is None:
        payload = Raw(random_payload(128))
    else:
        # ensure it's bytes
        payload = Raw(payload_bytes if isinstance(payload_bytes, (bytes, bytearray)) else str(payload_bytes).encode())

    # create IP object with optional TTL
    ip_kwargs = {}
    if ttl is not None:
        assert 0 <= ttl <= 255
        ip_kwargs['ttl'] = int(ttl)
    ip_pkt = IP(dst=dst_ip, **ip_kwargs)

    if proto == "tcp":
        return ip_pkt/ TCP(sport=sport, dport=dport, flags="S")/payload
    if proto == "udp":
        return ip_pkt/ UDP(sport=sport, dport=dport)/payload
    return ip_pkt/ ICMP()/payload

def build_ether_frame(proto, dst_ip, src_mac=None, dst_mac=None, sport=None, dport=None, payload_bytes=None, ttl=None):
    src_mac = src_mac or random_mac()
    dst_mac = dst_mac or random_mac()
    l3 = build_l3_packet(proto, dst_ip, sport, dport, payload_bytes, ttl)
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
    p.add_argument("--payload-hex", type=str, default=None, help="payload as hex string (e.g. deadbeef)")
    p.add_argument("--payload-file", type=str, default=None, help="read payload bytes from file (binary)")
    p.add_argument("--payload-text", type=str, default=None, help="payload as UTF-8 text")
    p.add_argument("--payload-size", type=int, default=None, help="random payload size in bytes (overrides default size)")
    p.add_argument("--ttl", type=int, default=None, help="fixed TTL for all packets (0-255)")
    p.add_argument("--ttl-range", type=int, nargs=2, metavar=('MIN','MAX'), default=None, help="random TTL range (inclusive) per packet")
    p.add_argument("--out-bytes", type=str, default="packets_bytes.txt", help="file with one byte per line, blank line between frames")
    p.add_argument("--out-pcap", type=str, default=None, help="optional pcap output")
    p.add_argument("--include-preamble", action="store_true", help="prepend Ethernet preamble+SFD (55..D5) to each frame")
    args = p.parse_args()

    # validate TTL args
    if args.ttl is not None:
        assert 0 <= args.ttl <= 255
    if args.ttl_range is not None:
        lo, hi = args.ttl_range
        assert 0 <= lo <= 255 and 0 <= hi <= 255 and lo <= hi

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

            # prepare payload bytes according to CLI args (per-packet; same payload for all packets unless randomized)
            payload_bytes = None
            if args.payload_hex:
                payload_bytes = bytes.fromhex(args.payload_hex)
            elif args.payload_file:
                with open(args.payload_file, "rb") as pf:
                    payload_bytes = pf.read()
            elif args.payload_text:
                payload_bytes = args.payload_text.encode("utf-8")
            elif args.payload_size is not None:
                payload_bytes = os.urandom(args.payload_size)

            # choose TTL for this packet
            ttl_val = None
            if args.ttl is not None:
                ttl_val = args.ttl
            elif args.ttl_range is not None:
                ttl_val = random.randint(args.ttl_range[0], args.ttl_range[1])

            frame = build_ether_frame(proto, dst_ip, sport=src_port, dport=dst_port, payload_bytes=payload_bytes, ttl=ttl_val)
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