#!/usr/bin/env bash

set -x

readonly with_databases="with-databases"
readonly without_databases="without-databases"
readonly mongodb_auto="mongodb-auto"
test_type="$1"

if [[ "$test_type" != "$with_databases" ]] && [[ "$test_type" != "$without_databases" ]] && [[ "$test_type" != "$mongodb_auto" ]]; then
  echo "Invalid test type (unknown '$test_type')" >&2
  exit 1
fi

test_etcd_connection() {
  local url="http://localhost:2379/health"
  curl --silent --fail-with-body "$url" > /dev/null
  rc=$?
  if [[ "$test_type" = "$with_databases" ]] && [[ $rc -eq 1 ]]; then
    echo "something wrong happened, etcd is not healthy" >&2
    exit 1
  fi

  if [[ "$test_type" = "$without_databases" ]] && [[ $rc -eq 0 ]]; then
    echo "something wrong happened, etcd should NOT be running" >&2
    exit 1
  fi

  if [[ "$test_type" = "$mongodb_auto" ]] && [[ $rc -eq 0 ]]; then
    echo "something wrong happened, etcd should NOT be running" >&2
    exit 1
  fi

  echo "everything is working as expected"
}

test_redis_connection() {
  docker exec redis redis-cli PING > /dev/null 2>&1
  rc=$?
  if [[ "$test_type" = "$with_databases" ]] && [[ $rc -eq 1 ]]; then
    echo "something wrong happened, Redis does not ping" >&2
    exit 1
  fi

  if [[ "$test_type" = "$without_databases" ]] && [[ $rc -eq 0 ]]; then
    echo "something wrong happened, Redis should NOT be running" >&2
    exit 1
  fi

  if [[ "$test_type" = "$mongodb_auto" ]] && [[ $rc -eq 0 ]]; then
    echo "something wrong happened, Redis should NOT be running" >&2
    exit 1
  fi

  echo "everything is working as expected"
}

test_mongodb_connection() {
  docker exec mongodb mongo --quiet --eval "db.runCommand({ ping: 1 })" > /dev/null
  rc=$?
  if [[ "$test_type" = "$with_databases" ]] && [[ $rc -eq 1 ]]; then
    echo "something wrong happened, MongoDB does not ping" >&2
    exit 1
  fi

  if [[ "$test_type" = "$mongodb_auto" ]] && [[ $rc -eq 1 ]]; then
    echo "something wrong happened, MongoDB does not ping" >&2
    exit 1
  fi

  if [[ "$test_type" = "$without_databases" ]] && [[ $rc -eq 0 ]]; then
    echo "something wrong happened, MongoDB should NOT be running" >&2
    exit 1
  fi

  echo "everything is working as expected"
}

test_etcd_connection
test_redis_connection
test_mongodb_connection
