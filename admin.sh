#!/bin/bash
PACKAGE="0x216003813310bc2f18db14e4f4c229b031a64efc24e81263d7e76fca5c902485"
CONFIG="0x05550d7ed3cfdf653b2f4cb4b84d0c28d976c8f214a36fa857345c8fb9e298e8"
ADMIN_CAP="0xef348ed2a480030a9c7b23ce4b39872812ded1bf5d72f47a8dac956e6b10eee4"
PUBLISHER="0xc59455006847502fc72ddb9ca55f63c2b9327d3e09556bdd6bf17d86ee0592ee"

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
    sui client call \
      --package "$PACKAGE" \
      --module stamp \
      --function new_event \
      --args "$CONFIG" "$ADMIN_CAP" "$EVENT_NAME" "$EVENT_DESCRIPTION" "$IMAGE_URL"
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
