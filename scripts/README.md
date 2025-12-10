# Network Packet Stress Test Scripts

Fast and reliable packet stress testing for your network implementation.

## 📦 Scripts

- **[stress_send.py](stress_send.py)** - Fast packet sender (requires sudo)
- **[stress_receive.py](stress_receive.py)** - Accurate packet receiver using tcpdump (requires sudo)
- **[count_packets.sh](count_packets.sh)** - Quick packet counter with Mbps calculation (requires sudo)

## 🚀 Quick Start

### Send and Receive 50,000 Packets

```bash
# Terminal 1 - Start receiver first
sudo python3 scripts/stress_receive.py 50000 1472 60

# Terminal 2 - Send packets
sudo python3 scripts/stress_send.py 50000 1472
```

### Quick Packet Count

```bash
sudo ./scripts/count_packets.sh en7 10 "udp port 53" 1518
```

## 📖 Usage

### stress_send.py

Fast packet sender optimized for macOS.

```bash
sudo python3 stress_send.py [count] [payload_size]
```

**Parameters:**
- `count`: Number of packets (default: 50000)
- `payload_size`: Payload bytes (default: 1472, max: 1472)

**Example:**
```bash
sudo python3 stress_send.py 100000 1472  # Send 100k packets
```

### stress_receive.py

High-accuracy receiver using tcpdump (no packet drops).

```bash
sudo python3 stress_receive.py [count] [payload_size] [timeout]
```

**Parameters:**
- `count`: Expected packets (default: 50000)
- `payload_size`: Expected payload bytes (default: 1472)
- `timeout`: Capture timeout in seconds (default: 60)

**Example:**
```bash
sudo python3 stress_receive.py 100000 1472 120
```

### count_packets.sh

Simple BPF-based packet counter with data rate calculation.

```bash
./count_packets.sh [interface] [duration] [filter] [frame_size]
```

**Parameters:**
- `interface`: Network interface (default: en7)
- `duration`: Capture duration in seconds (default: 10)
- `filter`: BPF filter (default: "udp and dst net 10.0.0.0/8 and dst port 53")
- `frame_size`: Frame size for rate calculation (default: 1518)

**Example:**
```bash
sudo ./count_packets.sh en7 30 "udp port 53" 1518
```

## 🔍 Packet Identification

Each packet is uniquely identifiable **two ways**:

### 1. Destination IP Encoding (24-bit)

Packet number encoded as `10.A.B.C`:
- Packet 0 → `10.0.0.0`
- Packet 1 → `10.0.0.1`
- Packet 255 → `10.0.0.255`
- Packet 256 → `10.0.1.0`
- Packet 65535 → `10.0.255.255`
- Packet 65536 → `10.1.0.0`
- Packet 1000000 → `10.15.66.64`

**Formula:** `IP = 10.(N>>16).((N>>8)&0xFF).(N&0xFF)`

**Max:** 16,777,216 unique packets

### 2. Payload Structure

- **First 8 bytes:** Counter (big-endian)
- **Remaining bytes:** Padding (0xAA)

## 📊 Frame Sizes

| Payload | Frame Size | Description |
|---------|-----------|-------------|
| 64 B | 110 B | Small |
| 512 B | 558 B | Medium |
| 1024 B | 1070 B | Large |
| **1472 B** | **1518 B** | **Maximum (recommended)** |

## 🔬 Wireshark Tips

### Count Filtered Packets

1. **Status Bar**: Apply filter, look at bottom: "Displayed: X"
2. **Statistics**: Statistics → Capture File Properties → "Displayed" count
3. **Custom Column**: Add column with Type: "Number"

### Filter Examples

```
# All test packets
udp.port == 53 and ip.dst >= 10.0.0.0 and ip.dst <= 10.255.255.255

# Specific packet by IP
ip.dst == 10.0.3.232  # Packet 1000

# By source
ip.src == 192.168.1.100 and udp.port == 53
```

### Decode IP to Packet Number

For IP `10.A.B.C`: Packet = `A × 65536 + B × 256 + C`

Example: `10.1.134.160` = `1×65536 + 134×256 + 160` = Packet 100000

## 📈 Output Analysis

The receiver provides:
- ✅ **Packet loss detection** (shows missing packet numbers)
- ✅ **Duplicate detection**
- ✅ **Out-of-order detection**
- ✅ **Throughput stats** (packets/sec, Mbps)
- ✅ **Payload validation**
- ✅ **IP encoding validation**

## ⚙️ Configuration

Both scripts default to:
- Sender interface: `en10`
- Receiver interface: `en7`
- Source IP: `192.168.1.100`
- Destination port: `53` (UDP)
- MAC addresses: `5a:65:7b:63:ba:d3`

Edit the scripts to match your network setup.

## 🐛 Troubleshooting

### Permission Errors
```bash
# All scripts require sudo
sudo python3 stress_send.py
sudo python3 stress_receive.py
sudo ./count_packets.sh
```

### No Packets Received

1. **Start receiver first** before sender
2. **Check interfaces** match your network setup
3. **Verify with count_packets.sh**:
   ```bash
   sudo ./count_packets.sh en7 10 "udp port 53" 1518
   ```

### Low Packet Rate

Expected performance:
- Sender: 10-30 Mbps (10k-25k pkt/s with 1518B frames)
- Receiver: No drops with tcpdump

## 💡 Tips

1. **Always start receiver before sender**
2. **Match packet_count and payload_size** on both sides
3. **Use 1472 byte payload** for maximum throughput
4. **Verify in Wireshark** for detailed analysis
5. **Use count_packets.sh** for quick validation

## 📝 Example Session

```bash
# Terminal 1: Start receiver for 50k packets
sudo python3 stress_receive.py 50000 1472 60

# Terminal 2: Send 50k packets
sudo python3 stress_send.py 50000 1472

# Terminal 3 (optional): Monitor in parallel
sudo ./count_packets.sh en7 10 "udp port 53" 1518
```

## 🎯 Expected Results

With 50,000 packets (1472 byte payload):
- **Total data**: ~75.7 MB
- **Estimated bandwidth**: ~605.6 Mb
- **Typical send time**: 5-10 seconds
- **Throughput**: 10-30 Mbps
- **Packet loss**: 0% (with proper setup)
