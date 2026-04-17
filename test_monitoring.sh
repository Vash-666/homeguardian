#!/bin/bash

# Quick test of monitoring modules

echo "Testing HomeGuardian monitoring modules..."
echo "=========================================="

# Test CPU monitor
echo "1. Testing CPU monitor..."
./monitoring/modules/cpu_monitor.sh > /tmp/cpu_test.json 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ CPU monitor passed"
    # Check if output ends with valid JSON
    tail -1 /tmp/cpu_test.json | python3 -m json.tool >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✓ CPU monitor returned valid JSON"
    else
        echo "  ✗ CPU monitor did not return valid JSON"
        tail -5 /tmp/cpu_test.json
    fi
else
    echo "  ✗ CPU monitor failed"
fi

# Test memory monitor
echo ""
echo "2. Testing memory monitor..."
./monitoring/modules/memory_monitor.sh > /tmp/memory_test.json 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ Memory monitor passed"
    tail -1 /tmp/memory_test.json | python3 -m json.tool >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✓ Memory monitor returned valid JSON"
    else
        echo "  ✗ Memory monitor did not return valid JSON"
        tail -5 /tmp/memory_test.json
    fi
else
    echo "  ✗ Memory monitor failed"
fi

# Test disk monitor
echo ""
echo "3. Testing disk monitor..."
./monitoring/modules/disk_monitor.sh > /tmp/disk_test.json 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ Disk monitor passed"
    tail -1 /tmp/disk_test.json | python3 -m json.tool >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✓ Disk monitor returned valid JSON"
    else
        echo "  ✗ Disk monitor did not return valid JSON"
        tail -5 /tmp/disk_test.json
    fi
else
    echo "  ✗ Disk monitor failed"
fi

echo ""
echo "=========================================="
echo "Test completed."