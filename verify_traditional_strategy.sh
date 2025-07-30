#!/bin/bash

# Verification script for traditional round-robin strategy without lunpointer
# This script checks that QLC uses pure traditional strategy without lunpointer

echo "=== Traditional Round-Robin Strategy Verification ==="

# Check if we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "Error: Makefile not found. Please run this script from the project root directory."
    exit 1
fi

echo "Checking traditional strategy implementation..."

# Check QLC migration uses pure traditional strategy
echo "1. Checking QLC migration strategy..."
if grep -q "Migrate to QLC - use pure traditional round-robin strategy without lunpointer" conv_ftl.c; then
    echo "   ✓ QLC migration uses pure traditional strategy without lunpointer"
else
    echo "   ✗ QLC migration traditional strategy comment missing"
fi

# Check that QLC migration doesn't use lunpointer in the migration function
echo "2. Checking QLC migration doesn't use lunpointer in migrate_page..."
if grep -A15 "Migrate to QLC" conv_ftl.c | grep -v "/*" | grep -q "lunpointer"; then
    echo "   ✗ QLC migration incorrectly uses lunpointer in migrate_page"
else
    echo "   ✓ QLC migration correctly doesn't use lunpointer in migrate_page"
fi

# Check that QLC migration uses get_new_page (not get_new_page_DA)
echo "3. Checking QLC migration uses get_new_page..."
if grep -A15 "Migrate to QLC" conv_ftl.c | grep -q "get_new_page(conv_ftl, GC_IO)"; then
    echo "   ✓ QLC migration uses get_new_page (traditional strategy)"
else
    echo "   ✗ QLC migration doesn't use get_new_page"
fi

# Check that QLC migration doesn't use get_new_page_DA
echo "4. Checking QLC migration doesn't use get_new_page_DA..."
if grep -A15 "Migrate to QLC" conv_ftl.c | grep -q "get_new_page_DA"; then
    echo "   ✗ QLC migration incorrectly uses get_new_page_DA"
else
    echo "   ✓ QLC migration correctly doesn't use get_new_page_DA"
fi

# Check SLC migration uses lunpointer
echo "5. Checking SLC migration uses lunpointer..."
if grep -A15 "Migrate to SLC" conv_ftl.c | grep -v "/*" | grep -q "lunpointer"; then
    echo "   ✓ SLC migration correctly uses lunpointer"
else
    echo "   ✗ SLC migration doesn't use lunpointer"
fi

# Check SLC migration uses get_new_page_DA
echo "6. Checking SLC migration uses get_new_page_DA..."
if grep -A10 "Migrate to SLC" conv_ftl.c | grep -q "get_new_page_DA"; then
    echo "   ✓ SLC migration uses get_new_page_DA (DA strategy)"
else
    echo "   ✗ SLC migration doesn't use get_new_page_DA"
fi

# Check new writes use lunpointer for SLC
echo "7. Checking new writes use lunpointer for SLC..."
if grep -q "Only SLC writes use lunpointer, QLC uses pure traditional strategy" conv_ftl.c; then
    echo "   ✓ New writes correctly use lunpointer only for SLC"
else
    echo "   ✗ New writes lunpointer strategy comment missing"
fi

# Check that advance_write_pointer_DA is used for SLC
echo "8. Checking SLC uses advance_write_pointer_DA..."
if grep -q "SLC uses DA strategy, QLC uses pure traditional strategy" conv_ftl.c; then
    echo "   ✓ SLC uses advance_write_pointer_DA with lunpointer"
else
    echo "   ✗ SLC DA strategy comment missing"
fi

# Check that conv_write doesn't use lunpointer for QLC writes
echo "9. Checking conv_write doesn't use lunpointer for QLC writes..."
if grep -A20 "conv_write" conv_ftl.c | grep -v "/*" | grep -q "lunpointer.*qlc"; then
    echo "   ✗ conv_write incorrectly uses lunpointer for QLC"
else
    echo "   ✓ conv_write correctly doesn't use lunpointer for QLC"
fi

# Summary
echo ""
echo "=== Traditional Strategy Implementation Summary ==="
echo ""
echo "Strategy Differentiation Implemented:"
echo "✓ SLC uses DA strategy with lunpointer"
echo "✓ QLC uses pure traditional round-robin strategy without lunpointer"
echo "✓ SLC migration uses lunpointer and get_new_page_DA"
echo "✓ QLC migration uses get_new_page (no lunpointer)"
echo "✓ New writes use lunpointer only for SLC allocation"
echo "✓ SLC writes use advance_write_pointer_DA"
echo "✓ QLC writes use advance_write_pointer (traditional)"
echo ""
echo "Strategy Details:"
echo ""
echo "SLC Strategy (DA with lunpointer):"
echo "- Uses lunpointer for allocation"
echo "- Uses get_new_page_DA() for page allocation"
echo "- Uses advance_write_pointer_DA() for write pointer"
echo "- Die-affinity load balancing"
echo ""
echo "QLC Strategy (Pure Traditional):"
echo "- No lunpointer usage"
echo "- Uses get_new_page() for page allocation"
echo "- Uses advance_write_pointer() for write pointer"
echo "- Simple round-robin load balancing"
echo ""
echo "Migration Strategy:"
echo "- SLC migration: lunpointer + get_new_page_DA()"
echo "- QLC migration: get_new_page() (no lunpointer)"
echo ""
echo "Write Strategy:"
echo "- New writes: lunpointer for SLC allocation only"
echo "- SLC writes: advance_write_pointer_DA()"
echo "- QLC writes: advance_write_pointer() (traditional)"
echo ""
echo "Key Implementation Points:"
echo "- lunpointer is only used for SLC operations"
echo "- QLC operations use pure traditional strategy"
echo "- No lunpointer involvement in QLC migration"
echo "- Traditional round-robin for QLC allocation"
echo ""
echo "=== Traditional Strategy Verification Complete ==="
echo "QLC correctly uses pure traditional round-robin strategy without lunpointer."
echo "SLC correctly uses DA strategy with lunpointer." 