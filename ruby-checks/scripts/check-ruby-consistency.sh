#!/usr/bin/env bash
#
# Check Ruby version consistency between .ruby-version and Dockerfile
#

ruby_version_dockerfile=$(grep "FROM ruby:" < Dockerfile | cut -d ":" -f 2)
ruby_version=$(cat .ruby-version)

if [[ "${ruby_version}" != "${ruby_version_dockerfile}" ]]; then
  echo "Ruby version in .ruby-version ($ruby_version) does not match Ruby version in Dockerfile ($ruby_version_dockerfile)"
  exit 1
else
  echo "Ruby version matches ($ruby_version)"
fi
