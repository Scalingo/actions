#!/usr/bin/env bash
#
# Start a Redis database in a Docker container, and wait for the database to be ping-able.
#

docker run --quiet --detach --rm --name redis \
  --publish 6379:6379 \
  redis:7.2.11 > /dev/null

echo -n "Waiting for Redis..."
for _ in {1..30}; do
  if docker exec redis redis-cli PING > /dev/null 2>&1; then
    echo -e "\nRedis is ready!"
    exit 0
  fi
  echo -n "."
  sleep 1
done
echo -e "\nRedis failed to start"
exit 1
