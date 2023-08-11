#!/bin/bash
 
scarb build
if [ $? != 0 ]; then
    echo $?
    exit 1
fi

source ./env
if [ $? != 0 ]; then
    echo $?
    exit 1
fi

# Read the file contents into a variable using command substitution
CONSTRUCTOR_FILE_OUTPUT=$(scarb cairo-run --available-gas 2000000)

CONSTRUCTOR_ARGS=$(echo "$CONSTRUCTOR_FILE_OUTPUT" | grep -o -E '0x[0-9a-f]+' | sed -e 's/^.*\(0x[0-9a-f]\+\).*$/\1/' | tr '\n' ' ')
# Check if the constructor args are empty
if [ -z "$CONSTRUCTOR_ARGS" ]; then
    echo "Constructor args are empty. Exiting..."
    exit 1
fi

# Print the constructor args
YELLOW='\033[1;33m' # Yellow color code
NC='\033[0m'  
echo "\n\nDeploying with constructor args: ${YELLOW}$CONSTRUCTOR_ARGS\n ${NC}"

# Deploy the contract
starkli deploy $AA_CLASS_HASH $CONSTRUCTOR_ARGS
