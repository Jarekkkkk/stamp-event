#!/bin/bash
PACKAGE="0x160397d745dbcf48d32a71215d1cf73357ca8971ccb8521431d3f730a9a6b10a"
CONFIG="0x57daf7c5e8ee4580d9b274e9730f1462de7773b88e74aeeb68b10b177a61e889"
ADMIN_CAP="0x867b48e4de3c701e0ca55593328f6cd8300343964a4a82fb266382c4ac85bad5"
PUBLISHER="0x28aeab5e3444a2f8b3261ed248fed476bc98dba34d3b92f503916176f709b4ac"

COMMAND=$1
shift

case "$COMMAND" in
  # new_collection
  new_collection)
    COLLECTION_TYPE=$1
    sui client call \
      --package $PACKAGE \
      --module stamp \
      --function new_collection \
      --type-args $COLLECTION_TYPE \
      --args $CONFIG $PUBLISHER
    ;;
  
  # new_event
  new_event)
    EVENT_NAME=$1
    EVENT_DESCRIPTION=$2
    IMAGE_URL=$3
    POINTS=$4
    sui client call \
      --package "$PACKAGE" \
      --module stamp \
      --function new_event \
      --args "$CONFIG" "$ADMIN_CAP" "$EVENT_NAME" "$EVENT_DESCRIPTION" "$IMAGE_URL" "$POINTS"
    ;;

  # mint_to
  mint_to)
    COLLECTION_TYPE=$1
    EVENT_NAME=$2
    RECIPIENT=$3
    sui client call \
      --package $PACKAGE \
      --module stamp \
      --function mint_to \
      --type-args $COLLECTION_TYPE \
      --args "$CONFIG" "$EVENT_NAME" "$RECIPIENT"
    ;;

  *)
    echo "Unknown command: $COMMAND"
    echo "Valid commands: add_works, add_stable, update_tier"
    ;;
esac
