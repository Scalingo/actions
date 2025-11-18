#!/usr/bin/env bash
#
# Start etcd in a Docker container, and wait for it to be healthy.
#

SC_ETCD_VERSION=${SC_ETCD_VERSION:="3.5.17"}

docker run --quiet --detach --rm --name etcd \
  --publish 2379:2379 \
  --publish 2380:2380 \
  "quay.io/coreos/etcd:v${SC_ETCD_VERSION}" \
    etcd --name node1 \
      --initial-advertise-peer-urls http://0.0.0.0:2380 \
      --listen-peer-urls http://0.0.0.0:2380 \
      --advertise-client-urls http://0.0.0.0:2379 \
      --listen-client-urls http://0.0.0.0:2379 \
      --initial-cluster node1=http://0.0.0.0:2380 \
      --initial-cluster-state new > /dev/null

echo -n "Waiting for etcd..."
for _ in {1..30}; do
  if docker exec etcd etcdctl endpoint health > /dev/null; then
    echo -e "\netcd ready!"
    exit 0
  fi
  echo -n "."
  sleep 1
done
echo -e "\netcd failed to start"
exit 1
