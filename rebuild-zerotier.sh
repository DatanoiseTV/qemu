#!/bin/bash
# Quick script to rebuild ZeroTier library with all required objects

set -e

echo "Rebuilding ZeroTier static library with all crypto objects..."

cd third_party/zerotier-src

# Clean and rebuild
echo "Building ZeroTier..."
make clean 2>/dev/null || true
make -j$(nproc) one

# Collect ALL object files including assembly crypto
echo "Collecting object files..."
OBJECT_FILES=""

# Core directories
for dir in node controller service osdep; do
    if [ -d "$dir" ]; then
        OBJ_FILES=$(find "$dir" -name "*.o" 2>/dev/null || true)
        if [ -n "$OBJ_FILES" ]; then
            OBJECT_FILES="$OBJECT_FILES $OBJ_FILES"
            echo "Found $(echo $OBJ_FILES | wc -w) object files in $dir/"
        fi
    fi
done

# External libraries including crypto assembly
for extdir in ext/miniupnpc ext/libnatpmp ext/http-parser ext/ed25519-amd64-asm; do
    if [ -d "$extdir" ]; then
        EXT_OBJ_FILES=$(find "$extdir" -name "*.o" 2>/dev/null || true)
        if [ -n "$EXT_OBJ_FILES" ]; then
            OBJECT_FILES="$OBJECT_FILES $EXT_OBJ_FILES"
            echo "Found $(echo $EXT_OBJ_FILES | wc -w) object files in $extdir/"
        fi
    fi
done

# Check for salsa objects
if [ -d "ext" ]; then
    SALSA_OBJ=$(find ext -name "*salsa*.o" 2>/dev/null || true)
    if [ -n "$SALSA_OBJ" ]; then
        OBJECT_FILES="$OBJECT_FILES $SALSA_OBJ"
        echo "Found salsa crypto objects: $SALSA_OBJ"
    fi
fi

if [ -z "$OBJECT_FILES" ]; then
    echo "Error: No object files found!"
    exit 1
fi

# Create the static library
echo "Creating static library with $(echo $OBJECT_FILES | wc -w) object files..."
ar rcs ../zerotier/libzerotier.a $OBJECT_FILES

# Check if successful
if [ -f "../zerotier/libzerotier.a" ]; then
    LIBSIZE=$(stat -c%s "../zerotier/libzerotier.a" 2>/dev/null || stat -f%z "../zerotier/libzerotier.a" 2>/dev/null || echo "unknown")
    echo "ZeroTier static library created successfully (size: ${LIBSIZE} bytes)"
    
    # Check for missing symbols
    echo "Checking for required symbols..."
    nm ../zerotier/libzerotier.a | grep -E "(salsa2012|ed25519)" | head -10
else
    echo "Error: Failed to create static library"
    exit 1
fi

cd ../..
echo "Done! Now run 'make' in the build directory."