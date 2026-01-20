#!/bin/bash
#
# This script executes the Go linter which checks if the Go version specified in the go.mod is compatible with the Go version in the Dockerfile.
#
# /!\ Any modification to this script should be uploaded to S3. Instructions are in the README.
#

set -o errexit

if [[ "$DEBUG" = "true" ]]; then
  set -x
fi

function go_versions_match {
  local go_version_gomod
  go_version_gomod=$(go list -m -json -mod=readonly | jq --raw-output "select(.Main == true) | .GoVersion")
  local go_version_dockerfile
  go_version_dockerfile=$(grep "FROM golang:" < Dockerfile | cut -d ":" -f 2)

  local go_major_version_gomod go_minor_version_gomod go_patch_version_gomod
  go_major_version_gomod="$(echo "$go_version_gomod" | cut -d "." -f1)"
  go_minor_version_gomod="$(echo "$go_version_gomod" | cut -d "." -f2)"
  go_patch_version_gomod="$(echo "$go_version_gomod" | cut -d "." -f3)"

  local go_major_version_dockerfile go_minor_version_dockerfile go_patch_version_dockerfile
  go_major_version_dockerfile="$(echo "$go_version_dockerfile" | cut -d "." -f1)"
  go_minor_version_dockerfile="$(echo "$go_version_dockerfile" | cut -d "." -f2)"
  go_patch_version_dockerfile="$(echo "$go_version_dockerfile" | cut -d "." -f3)"

  if [[ "$go_major_version_gomod" -ne "$go_major_version_dockerfile" ]]; then
    echo "Go major version does not match between go.mod and Dockerfile ($go_version_gomod == $go_version_dockerfile)" >&2
    return 1
  fi

  # At this point, the major versions are equal

  if [[ "$go_minor_version_dockerfile" -lt "$go_minor_version_gomod" ]]; then
    echo "Dockerfile Go version must be greater than the go.mod one. Incompatible minor version ($go_version_gomod and $go_version_dockerfile)" >&2
    return 1
  fi

  if [[ "$go_minor_version_dockerfile" -gt "$go_minor_version_gomod" ]]; then
    echo "Go minor versions compatible between go.mod and Dockerfile ($go_version_gomod and $go_version_dockerfile)"
    return 0
  fi

  # At this point, the major and minor versions are equal

  # If both declared versions don't include a patch version
  if [[ -z "$go_patch_version_dockerfile" ]] && [[ -z "$go_patch_version_gomod" ]]; then
    echo "Dockerfile and go.mod Go versions are equal without patch version ($go_version_gomod == $go_version_dockerfile)"
    return 0
  fi

  if [[ -z "$go_patch_version_dockerfile" ]]; then
    echo "Dockerfile Go version is a compatible minor version as declared in go.mod ($go_version_gomod and $go_version_dockerfile)"
    return 0
  fi

  if [[ -z "$go_patch_version_gomod" ]]; then
    echo "Dockerfile Go version must be equal to go.mod ($go_version_gomod and $go_version_dockerfile)"
    return 0
  fi

  # Both go.mod and Dockerfile declare a patch version

  if [[ "$go_patch_version_dockerfile" -lt "$go_patch_version_gomod" ]]; then
    echo "Dockerfile Go version must be greater than the go.mod one. Incompatible patch version ($go_version_gomod and $go_version_dockerfile)" >&2
    return 1
  fi

  echo "go.mod and Dockerfile are compatible ($go_version_gomod == $go_version_dockerfile)"
}

# If the script is executed, execute the function.
# This is the case when the script is executed via GitHub Action.
# If the script is executed in CodeShip, we source and execute it in the `lint` script.
if [[ "$0" = "${BASH_SOURCE[0]}" ]]; then
  if [[ -f Dockerfile ]]; then
    go_versions_match
  else
    echo "There is no Dockerfile to check the Go version"
  fi
fi
