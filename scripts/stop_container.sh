#!/bin/bash
# Stop and remove any container from a previous deployment.
# No `set -e` — this must succeed when nothing is running.

CONTAINER_ID=$(docker ps -q --filter "publish=5000")

if [ -n "$CONTAINER_ID" ]; then
  echo "Stopping container $CONTAINER_ID"
  docker rm -f "$CONTAINER_ID"
else
  echo "No running container found"
fi

exit 0
