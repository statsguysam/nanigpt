#!/bin/bash
# build_cactus.sh
# Single-shot script that produces apple/cactus-ios.xcframework for the iOS app.
# Run this from your Mac's Terminal:
#
#   bash "/Users/salimshaikh/Documents/Claude/Projects/Gemma Kaggle Hack/build_cactus.sh"
#
# Time: 5-15 minutes depending on your Mac's CPU.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "==> Cactus iOS xcframework builder"
echo ""

# 1. Sanity: Xcode command-line tools must be installed
if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}Xcode command-line tools not found.${NC}"
    echo "Install with: xcode-select --install"
    exit 1
fi
echo -e "${GREEN}OK: Xcode command-line tools${NC}"

# 2. CMake
if ! command -v cmake &>/dev/null; then
    echo -e "${YELLOW}CMake not found. Installing via Homebrew...${NC}"
    if ! command -v brew &>/dev/null; then
        echo -e "${RED}Homebrew not installed. Install it from https://brew.sh first.${NC}"
        exit 1
    fi
    brew install cmake
fi
echo -e "${GREEN}OK: cmake $(cmake --version | head -1 | awk '{print $3}')${NC}"

# 3. Clone the cactus repo into ~/Downloads (idempotent)
mkdir -p ~/Downloads
cd ~/Downloads
if [ ! -d cactus ]; then
    echo "Cloning cactus-compute/cactus..."
    git clone --depth 1 https://github.com/cactus-compute/cactus
fi
cd cactus
echo -e "${GREEN}OK: cactus repo at $(pwd)${NC}"

# 4. Run their setup (creates Python venv, configures git hooks, installs deps)
echo "Running cactus setup (Python venv + dependencies)..."
# Skip git config check by ensuring we have one set
if [ -z "$(git config user.name 2>/dev/null)" ]; then
    git config user.name "$(whoami)"
fi
if [ -z "$(git config user.email 2>/dev/null)" ]; then
    git config user.email "$(whoami)@local"
fi
# shellcheck disable=SC1091
source ./setup
echo -e "${GREEN}OK: cactus environment ready${NC}"

# 5. Run the actual build
echo "Building cactus for Apple platforms (this is the long part)..."
echo "Output will be quieted; watch CPU activity for progress."
cactus build --apple

# 6. Verify the artifacts
XCFRAMEWORK="$(pwd)/apple/cactus-ios.xcframework"
SWIFT_FILE="$(pwd)/apple/Cactus.swift"

if [ -d "$XCFRAMEWORK" ] && [ -f "$SWIFT_FILE" ]; then
    echo ""
    echo -e "${GREEN}===== BUILD COMPLETE =====${NC}"
    echo ""
    echo "Files ready to drag into Xcode:"
    echo "  $XCFRAMEWORK"
    echo "  $SWIFT_FILE"
    echo ""
    echo "Next steps in Xcode:"
    echo "  1. Drag cactus-ios.xcframework into the project navigator. Set 'Embed & Sign' under General > Frameworks."
    echo "  2. Drag Cactus.swift into the project navigator. Target NaniGPT, copy items if needed."
    echo "  3. Make sure you removed the broken 'cactus' Swift Package dependency under Package Dependencies."
    echo "  4. Cmd+R to build."
    echo ""
    echo "Reveal in Finder:"
    open "$(pwd)/apple"
else
    echo ""
    echo -e "${RED}Build appears to have failed. Expected files not found.${NC}"
    echo "Looked for:"
    echo "  $XCFRAMEWORK"
    echo "  $SWIFT_FILE"
    echo ""
    echo "Re-run with verbose output:"
    echo "  cd ~/Downloads/cactus && cactus build --apple"
    exit 1
fi
