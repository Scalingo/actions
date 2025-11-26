#!/usr/bin/env bash
#
# Start a MongoDB database in a Docker container, and wait for the database to be ready.
#

docker run --quiet --detach --rm --name mongodb \
  --publish 27017:27017 \
  mongo:4.0 > /dev/null

echo -n "Waiting for MongoDB..."
for _ in {1..30}; do
  if docker exec mongodb mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1 || \
     docker exec mongodb mongo --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo -e "\nMongoDB is ready!"
    exit 0
  fi
  echo -n "."
  sleep 1
done
echo -e "\nMongoDB failed to start"
exit 1
