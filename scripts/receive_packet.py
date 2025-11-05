from scapy.all import sniff

pkts = sniff(iface="en0", count=10)
for p in pkts:
    print(p.summary())
