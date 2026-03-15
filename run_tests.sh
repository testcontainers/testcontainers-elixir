#!/usr/bin/env bash
set -o pipefail

TOTAL_RUNS=10
CLEANUP_IMAGES=false
FAILURES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup-images) CLEANUP_IMAGES=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

for i in $(seq 1 $TOTAL_RUNS); do
  echo "========================================"
  echo "Run $i/$TOTAL_RUNS"
  echo "========================================"

  echo "Cleaning up Docker containers..."
  docker rm -f $(docker ps -aq) &>/dev/null
  if [ "$CLEANUP_IMAGES" = true ]; then
    echo "Cleaning up Docker images..."
    docker rmi -f $(docker images -q) &>/dev/null
  fi

  echo "Running tests..."
  output=$(MIX_ENV=test mix test 2>&1)
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    # Extract failed test details
    failed_tests=$(echo "$output" | grep -E "^\s+[0-9]+\)" -A 20 | head -100)
    summary=$(echo "$output" | grep -E "(Finished in |[0-9]+ failures|[0-9]+ invalid)" | tail -5)

    FAILURES+=("Run $i: exit code $exit_code")
    echo "FAILED on run $i"
    echo "$summary"
    echo "$failed_tests"
    echo ""
    echo "--- Full output saved to test_run_${i}.log ---"
    echo "$output" > "test_run_${i}.log"
  else
    echo "PASSED"
  fi

  echo ""
done

echo "========================================"
echo "Summary: $TOTAL_RUNS runs completed"
echo "========================================"

if [ ${#FAILURES[@]} -eq 0 ]; then
  echo "All $TOTAL_RUNS runs passed!"
else
  echo "${#FAILURES[@]} run(s) failed:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
