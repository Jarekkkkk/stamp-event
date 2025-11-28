#!/bin/bash
PACKAGE="0x71ace10bed80a93f30bc296c1622a10c2956f87f93393c200e401ef735ad8cb4"
CONFIG="0x5e5705f3497757d8e120e51143e81dab8e58d24ff1ba9bcf1e4af6c4b756fb9f"
ADMIN_CAP="0x535681c0cd88aea86ef321958c3dff33ea3aa3e5400ddd9f44fb57f214ed0f66"
PUBLISHER="0xfca2f7ec19fa71acad6ea7fbc5301da7bcb614a58bc37d40d2f3f6cbe5cd8c98"

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

  # add_manager
  add_manager)
    MANAGER=$1
    sui client call \
      --package "$PACKAGE" \
      --module stamp \
      --function add_manager \
      --args "$CONFIG" "$ADMIN_CAP" "$MANAGER"
    ;;

  # remove_manager
  remove_manager)
    MANAGER=$1
    sui client call \
      --package "$PACKAGE" \
      --module stamp \
      --function remove_manager \
      --args "$CONFIG" "$ADMIN_CAP" "$MANAGER"
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
