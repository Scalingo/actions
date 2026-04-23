#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
python3 -m unittest discover -s pull-request-compliance/tests -p 'test_*.py' -v
