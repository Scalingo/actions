#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
ruby -Iisms-change-management isms-change-management/tests/test_check_isms_change.rb
