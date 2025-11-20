#!/usr/bin/env bash
#
# Start a MongoDB database in a Docker container, and wait for the database to be ping-able.
#

mongodb_version="4.0.28"
username="admin"
password="admin"
database="mydb"

docker run --quiet --detach --rm --name mongodb \
  --publish 27017:27017 \
  --env "MONGO_INITDB_ROOT_USERNAME=$username" \
  --env "MONGO_INITDB_ROOT_PASSWORD=$password" \
  --env "MONGO_INITDB_DATABASE=$database" \
  "mongo:$mongodb_version" > /dev/null

connection_string="mongodb://${username}:${password}@localhost:27017/$database?connect=direct&authSource=admin"
echo "MONGO_URL=$connection_string" >> "$GITHUB_ENV"

echo -n "Waiting for MongoDB..."
for _ in {1..30}; do
  if docker exec mongodb mongo --quiet --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; then
    echo -e "\nMongoDB ready!"
    exit 0
  fi
  echo -n "."
  sleep 1
done
echo -e "\nMongoDB failed to start"
exit 1
