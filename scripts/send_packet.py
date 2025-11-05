
from scapy.all import Ether, sendp, hexdump

dst_mac = "5a:65:7b:63:ba:d3"
src_mac = "5a:65:7b:63:ba:d3"   
iface = "en0"                 

eth = Ether(dst=dst_mac, src=src_mac, type=0x88B5)
payload = b"hello world from scapy" 

pkt = eth / payload

print("Frame summary:", pkt.summary())
hexdump(bytes(pkt))

sendp(pkt, iface=iface, count=10, inter=0.5)  
