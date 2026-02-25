#!/usr/bin/env bash
# Check if source uses any bun.* APIs not in the known shim list.
#
# Usage: ./scripts/check-shim.sh
#
# Prints new APIs that consumers need to add to their bun.zig shim.

set -euo pipefail

KNOWN="bun.JSError
bun.StackCheck
bun.StackCheck.init
bun.StackOverflow
bun.StringHashMapUnmanaged
bun.bit_set.StaticBitSet
bun.strings.codepointSize
bun.strings.decodeWTF
bun.strings.encodeWTF
bun.strings.eqlCaseInsensitiveASCIIICheckLength
bun.strings.eqlCaseInsensitiveASCIIIgnoreLength
bun.strings.indexOfAny
bun.strings.indexOfCharPos
bun.throwStackOverflow"

USED=$(grep -roh 'bun\.[a-zA-Z_.]*' src/ | sort -u)
NEW=$(comm -23 <(echo "$USED") <(echo "$KNOWN" | sort))

if [ -z "$NEW" ]; then
    echo "✓ All bun.* APIs covered by shim"
else
    echo "New bun.* APIs — consumers must update their shim:"
    echo "$NEW" | sed 's/^/  /'
    exit 1
fi
