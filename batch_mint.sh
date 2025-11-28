#!/bin/bash

PACKAGE="0x71ace10bed80a93f30bc296c1622a10c2956f87f93393c200e401ef735ad8cb4"
CONFIG="0x5e5705f3497757d8e120e51143e81dab8e58d24ff1ba9bcf1e4af6c4b756fb9f"
ADMIN_CAP="0x535681c0cd88aea86ef321958c3dff33ea3aa3e5400ddd9f44fb57f214ed0f66"

CSV_FILE=$1
COLLECTION_TYPE=$2
EVENT_NAME=$3

BATCH_SIZE=500
COUNTER=0
addresses=()

if [[ -z "$CSV_FILE" || -z "$COLLECTION_TYPE" || -z "$EVENT_NAME" ]]; then
    echo "Usage: ./batch_mint.sh <csv_file> <collection_type> <event_name>"
    exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
    echo "CSV file not found: $CSV_FILE"
    exit 1
fi

# Function: sanitize & convert addresses into proper Sui vector<address> string
build_vector_arg() {
    local input_addresses=("$@")
    local clean_addresses=()
    
    for addr in "${input_addresses[@]}"; do
        addr=$(echo "$addr" | tr -d '\r' | xargs)  # remove CR and spaces
        clean_addresses+=("@$addr")
    done
    
    # join with commas and wrap with correct vector<address> type
    echo "vector[ $(IFS=,; echo "${clean_addresses[*]}") ]"
}

echo "Starting batch mint from $CSV_FILE for event '$EVENT_NAME'"

# Read each line from CSV (no header)
while read -r RECIPIENT; do
    [[ -z "$RECIPIENT" ]] && continue
    
    addresses+=("$RECIPIENT")
    ((COUNTER++))
    
    if (( COUNTER == BATCH_SIZE )); then
        VECTOR_ARG=$(build_vector_arg "${addresses[@]}")
        
        echo "Submitting on-chain batch of $BATCH_SIZE..."
        echo "Vector argument: $VECTOR_ARG"
        
        # String must be double-quoted and wrapped in single quotes for shell
        sui client ptb \
            --assign v "$VECTOR_ARG" \
            --move-call "${PACKAGE}::stamp::batch_mint<${COLLECTION_TYPE}>" @"$CONFIG" '"'"$EVENT_NAME"'"' v \
            --dry-run
        
        echo "Batch complete."
        
        addresses=()
        COUNTER=0
        sleep 0.5
    fi
done < "$CSV_FILE"

# Process leftover addresses (<BATCH_SIZE)
if (( COUNTER > 0 )); then
    VECTOR_ARG=$(build_vector_arg "${addresses[@]}")
    
    echo "Submitting final batch of $COUNTER..."
    
    # String must be double-quoted and wrapped in single quotes for shell
    sui client ptb \
        --assign v "$VECTOR_ARG" \
        --move-call "${PACKAGE}::stamp::batch_mint<${COLLECTION_TYPE}>" @"$CONFIG" '"'"$EVENT_NAME"'"' v \
        --dry-run
    
    echo "Final batch complete."
fi
