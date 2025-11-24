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

healthcheck_cmd="endpoint health"
if [[ "$SC_ETCD_VERSION" == 3.3* ]]; then
  # This is needed for the etcd-discovery tests. For an unknown reason, they fail with etcd > 3.3.
  echo "etcd 3.3, use a specific health check command"
  healthcheck_cmd="cluster-health"
fi

echo -n "Waiting for etcd..."
for _ in {1..30}; do
  # `healthcheck_cmd` is not surrounded by double quotes and this is on purpose as it may contain multiple words.
  # shellcheck disable=SC2086
  if docker exec etcd etcdctl $healthcheck_cmd > /dev/null; then
    echo -e "\netcd ready!"
    exit 0
  fi
  echo -n "."
  sleep 1
done
echo -e "\netcd failed to start"
exit 1
