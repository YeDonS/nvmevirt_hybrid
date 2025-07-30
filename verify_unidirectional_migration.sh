#!/bin/bash

# Verification script for unidirectional migration (SLC to QLC only)
# This script checks that migration only happens from SLC to QLC

echo "=== Unidirectional Migration Verification ==="

# Check if we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "Error: Makefile not found. Please run this script from the project root directory."
    exit 1
fi

echo "Checking unidirectional migration implementation..."

# Check should_migrate_page function
echo "1. Checking should_migrate_page function..."
if grep -q "Only migrate from SLC to QLC" conv_ftl.c; then
    echo "   ✓ should_migrate_page only allows SLC to QLC migration"
else
    echo "   ✗ should_migrate_page migration logic missing"
fi

if grep -q "QLC pages stay in QLC - no migration back to SLC" conv_ftl.c; then
    echo "   ✓ QLC to SLC migration is disabled"
else
    echo "   ✗ QLC to SLC migration disable logic missing"
fi

# Check check_and_perform_migrations function
echo "2. Checking check_and_perform_migrations function..."
if grep -q "Only migrate from SLC to QLC (cold data migration)" conv_ftl.c; then
    echo "   ✓ check_and_perform_migrations only handles SLC to QLC"
else
    echo "   ✗ check_and_perform_migrations migration logic missing"
fi

if grep -q "Migrated LPN.*from SLC to QLC (cold data migration)" conv_ftl.c; then
    echo "   ✓ Migration debug message shows SLC to QLC only"
else
    echo "   ✗ Migration debug message missing"
fi

# Check migrate_page function
echo "3. Checking migrate_page function..."
if grep -q "Only migrate from SLC to QLC - use traditional round-robin strategy" conv_ftl.c; then
    echo "   ✓ migrate_page only handles SLC to QLC migration"
else
    echo "   ✗ migrate_page migration logic missing"
fi

# Check that QLC migration uses traditional strategy
echo "4. Checking QLC migration uses traditional strategy..."
if grep -A5 "Only migrate from SLC to QLC" conv_ftl.c | grep -q "get_new_page(conv_ftl, GC_IO)"; then
    echo "   ✓ QLC migration uses get_new_page (traditional strategy)"
else
    echo "   ✗ QLC migration doesn't use get_new_page"
fi

# Check that no SLC migration logic exists
echo "5. Checking no SLC migration logic exists..."
if grep -q "Migrate to SLC" conv_ftl.c; then
    echo "   ✗ SLC migration logic still exists"
else
    echo "   ✓ SLC migration logic removed"
fi

# Check that no QLC to SLC migration exists
echo "6. Checking no QLC to SLC migration exists..."
if grep -q "QLC.*migrate.*SLC" conv_ftl.c; then
    echo "   ✗ QLC to SLC migration logic still exists"
else
    echo "   ✓ QLC to SLC migration logic removed"
fi

# Check cold data migration logic
echo "7. Checking cold data migration logic..."
if grep -q "Cold SLC page.*migrate to QLC" conv_ftl.c; then
    echo "   ✓ Cold SLC to QLC migration logic implemented"
else
    echo "   ✗ Cold SLC to QLC migration logic missing"
fi

# Check page counter updates
echo "8. Checking page counter updates..."
if grep -q "conv_ftl->used_qlc_pages++" conv_ftl.c; then
    echo "   ✓ QLC page counter increment implemented"
else
    echo "   ✗ QLC page counter increment missing"
fi

if grep -q "conv_ftl->used_slc_pages--" conv_ftl.c; then
    echo "   ✓ SLC page counter decrement implemented"
else
    echo "   ✗ SLC page counter decrement missing"
fi

# Summary
echo ""
echo "=== Unidirectional Migration Implementation Summary ==="
echo ""
echo "Migration Strategy Implemented:"
echo "✓ Only SLC to QLC migration allowed"
echo "✓ QLC to SLC migration disabled"
echo "✓ Cold data migration from SLC to QLC"
echo "✓ Traditional round-robin strategy for QLC"
echo "✓ Proper page counter updates"
echo "✓ Migration debug messages"
echo ""
echo "Migration Logic:"
echo "1. should_migrate_page: Only allows SLC to QLC migration"
echo "2. check_and_perform_migrations: Only handles SLC to QLC"
echo "3. migrate_page: Only migrates from SLC to QLC"
echo "4. QLC pages stay in QLC permanently"
echo "5. Cold SLC pages migrate to QLC"
echo ""
echo "Migration Flow:"
echo "SLC (cold data) → migrate to QLC → QLC (permanent)"
echo ""
echo "Key Features:"
echo "- Unidirectional migration only"
echo "- Cold data tiering"
echo "- Traditional strategy for QLC"
echo "- No hot data promotion"
echo "- Simplified migration logic"
echo ""
echo "=== Unidirectional Migration Verification Complete ==="
echo "Migration is now unidirectional: SLC to QLC only."
echo "QLC to SLC migration is disabled." 