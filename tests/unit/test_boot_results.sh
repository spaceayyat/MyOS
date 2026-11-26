#!/usr/bin/env bash
# Unit tests for the boot-test parser. Needs bash and python3.
set -euo pipefail
python3 "$(dirname "${BASH_SOURCE[0]}")/check_boot_results.py"
