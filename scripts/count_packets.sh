#!/bin/bash
# Accurate packet counter using tcpdump with BPF filter
# Usage: ./count_packets.sh [interface] [duration] [filter] [packet_size]
#
# Examples:
#   ./count_packets.sh en7 10 "udp port 53" 1518
#   ./count_packets.sh en7 30 "src 192.168.1.100" 1518

IFACE="${1:-en7}"
DURATION="${2:-10}"
FILTER="${3:-udp and dst net 10.0.0.0/8 and dst port 53}"
FRAME_SIZE="${4:-1518}"  # Default: maximum Ethernet frame size

echo "==================================================="
echo "Packet Counter using tcpdump + BPF"
echo "==================================================="
echo "Interface: $IFACE"
echo "Duration: ${DURATION}s"
echo "Filter: $FILTER"
echo "Expected frame size: $FRAME_SIZE bytes"
echo "==================================================="
echo ""
echo "Starting capture..."
echo "Press Ctrl+C to stop early"
echo ""

# Create temporary file for capture
TMPFILE=$(mktemp /tmp/pcap_count.XXXXXX)

# Record start time
START_TIME=$(date +%s.%N)

# Run tcpdump
sudo tcpdump -i "$IFACE" -c 1000000 -w "$TMPFILE" "$FILTER" 2>&1 &
TCPDUMP_PID=$!

# Wait for duration or until tcpdump finishes
sleep "$DURATION" 2>/dev/null

# Record end time
END_TIME=$(date +%s.%N)

# Stop tcpdump if still running
if ps -p $TCPDUMP_PID > /dev/null 2>&1; then
    sudo kill -INT $TCPDUMP_PID 2>/dev/null
    sleep 1
fi

# Calculate actual duration
ACTUAL_DURATION=$(echo "$END_TIME - $START_TIME" | bc)

echo ""
echo "==================================================="
echo "RESULTS"
echo "==================================================="

# Count packets in the capture file
if [ -f "$TMPFILE" ]; then
    PACKET_COUNT=$(sudo tcpdump -r "$TMPFILE" 2>/dev/null | wc -l)
    echo "Total packets captured: $PACKET_COUNT"
    echo "Actual capture duration: ${ACTUAL_DURATION}s"

    # Calculate rates
    if (( $(echo "$ACTUAL_DURATION > 0" | bc -l) )); then
        RATE=$(echo "scale=2; $PACKET_COUNT / $ACTUAL_DURATION" | bc)
        echo "Average packet rate: $RATE packets/sec"

        # Calculate data rate in Mbps
        TOTAL_BITS=$(echo "$PACKET_COUNT * $FRAME_SIZE * 8" | bc)
        DATA_RATE=$(echo "scale=2; $TOTAL_BITS / $ACTUAL_DURATION / 1000000" | bc)
        TOTAL_MB=$(echo "scale=2; $PACKET_COUNT * $FRAME_SIZE / 1000000" | bc)

        echo "Average data rate: ${DATA_RATE} Mbps"
        echo "Total data: ${TOTAL_MB} MB"

        # Calculate line utilization (assuming 1 Gbps)
        LINE_UTIL=$(echo "scale=1; $DATA_RATE / 1000 * 100" | bc)
        echo "Line utilization: ${LINE_UTIL}% of 1 Gbps"
    fi

    # Show first few packets
    echo ""
    echo "First 10 packets:"
    sudo tcpdump -r "$TMPFILE" -nn 2>/dev/null | head -10
    echo ""

    # Cleanup
    rm -f "$TMPFILE"
else
    echo "Error: Capture file not created"
fi

echo "==================================================="
