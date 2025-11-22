#!/usr/bin/env bats

# Tests for retry-utils.sh
# Tests the retry_azure_operation function with various scenarios

setup() {
  # Source the retry utilities
  source "${BATS_TEST_DIRNAME}/../scripts/retry-utils.sh"

  # Create a temporary directory for test artifacts
  export TEST_TEMP_DIR="${BATS_TEST_TMPDIR}/retry-utils-test"
  mkdir -p "${TEST_TEMP_DIR}"

  # Mock Azure CLI by creating a temporary executable
  export MOCK_AZ_PATH="${TEST_TEMP_DIR}/az"
  export PATH="${TEST_TEMP_DIR}:${PATH}"

  # Set retry configuration for faster tests (must be integer for bash arithmetic)
  export RETRY_BASE_DELAY=1
}

teardown() {
  # Clean up temporary directory
  rm -rf "${TEST_TEMP_DIR}"
}

# Helper function to create a mock az command
create_mock_az() {
  local behavior="$1"

  cat > "${MOCK_AZ_PATH}" << 'EOF'
#!/bin/bash
BEHAVIOR="${AZ_MOCK_BEHAVIOR:-success}"

case "${BEHAVIOR}" in
  success)
    echo "Operation succeeded"
    exit 0
    ;;
  transient_failure)
    # Fail on first attempt, succeed on second
    if [ ! -f /tmp/az_attempt_count ]; then
      echo "1" > /tmp/az_attempt_count
      echo "Error: ServiceUnavailable (503)" >&2
      exit 1
    else
      ATTEMPTS=$(cat /tmp/az_attempt_count)
      if [ "${ATTEMPTS}" -lt 2 ]; then
        echo "$((ATTEMPTS + 1))" > /tmp/az_attempt_count
        echo "Error: TooManyRequests (429)" >&2
        exit 1
      else
        rm -f /tmp/az_attempt_count
        echo "Operation succeeded after retries"
        exit 0
      fi
    fi
    ;;
  permanent_failure)
    echo "Error: AuthorizationFailed - Access denied" >&2
    exit 1
    ;;
  scope_locked)
    echo "Error: ScopeLocked - Resource is locked" >&2
    exit 1
    ;;
  always_fail)
    echo "Error: Unknown error" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "${MOCK_AZ_PATH}"
}

@test "retry_azure_operation: successful operation on first attempt" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="success"

  run retry_azure_operation 3 "Test operation" az resource list

  [ "$status" -eq 0 ]
  [[ "${output}" == *"Attempt 1/3"* ]]
  [[ "${output}" == *"Operation succeeded"* ]]
}

@test "retry_azure_operation: successful operation after transient failures" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="transient_failure"
  rm -f /tmp/az_attempt_count

  run retry_azure_operation 5 "Test operation" az resource list

  [ "$status" -eq 0 ]
  [[ "${output}" == *"Attempt 1/5"* ]]
  # Should show transient error messages (503/429)
  [[ "${output}" == *"Service unavailable"* ]] || [[ "${output}" == *"Rate limit"* ]]
  [[ "${output}" == *"Retrying"* ]]
  [[ "${output}" == *"Operation succeeded after retries"* ]]

  # Clean up
  rm -f /tmp/az_attempt_count
}

@test "retry_azure_operation: permanent failure (AuthorizationFailed)" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="permanent_failure"

  run retry_azure_operation 5 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Attempt 1/5"* ]]
  [[ "${output}" == *"Permanent failure detected"* ]]
  [[ "${output}" == *"AuthorizationFailed"* ]]
  # Should NOT retry on permanent failures
  [[ "${output}" != *"Attempt 2/5"* ]]
}

@test "retry_azure_operation: scope locked error" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="scope_locked"

  run retry_azure_operation 5 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Attempt 1/5"* ]]
  [[ "${output}" == *"Resource is locked"* ]]
  [[ "${output}" == *"ScopeLocked"* ]]
  # Should NOT retry on locked resources
  [[ "${output}" != *"Attempt 2/5"* ]]
}

@test "retry_azure_operation: fails after max attempts" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="always_fail"

  run retry_azure_operation 3 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Attempt 1/3"* ]]
  [[ "${output}" == *"Attempt 2/3"* ]]
  [[ "${output}" == *"Attempt 3/3"* ]]
  [[ "${output}" == *"Failed after 3 attempts"* ]]
}

@test "retry_azure_operation: respects RETRY_BASE_DELAY" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="always_fail"
  export RETRY_BASE_DELAY=1

  START_TIME=$(date +%s)
  run retry_azure_operation 2 "Test operation" az resource list
  END_TIME=$(date +%s)

  [ "$status" -eq 1 ]

  # Should take at least 1 second (one retry with 1s delay)
  # but less than 5 seconds (generous buffer for slow systems)
  ELAPSED=$((END_TIME - START_TIME))
  [ "${ELAPSED}" -ge 1 ]
  [ "${ELAPSED}" -lt 5 ]
}

@test "retry_azure_operation: handles commands with arguments" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="success"

  run retry_azure_operation 3 "Test operation" az resource delete --ids "/subscriptions/test"

  [ "$status" -eq 0 ]
  [[ "${output}" == *"Operation succeeded"* ]]
}

@test "retry_azure_operation: identifies rate limit errors" {
  create_mock_az

  # Create a mock that returns rate limit error
  cat > "${MOCK_AZ_PATH}" << 'EOF'
#!/bin/bash
echo "Error: TooManyRequests (429)" >&2
exit 1
EOF
  chmod +x "${MOCK_AZ_PATH}"

  run retry_azure_operation 2 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Rate limit (429)"* ]]
  [[ "${output}" == *"Retrying"* ]]
}

@test "retry_azure_operation: identifies service unavailable errors" {
  create_mock_az

  # Create a mock that returns service unavailable error
  cat > "${MOCK_AZ_PATH}" << 'EOF'
#!/bin/bash
echo "Error: ServiceUnavailable (503)" >&2
exit 1
EOF
  chmod +x "${MOCK_AZ_PATH}"

  run retry_azure_operation 2 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Service unavailable (503)"* ]]
  [[ "${output}" == *"Retrying"* ]]
}

@test "retry_azure_operation: identifies gateway timeout errors" {
  create_mock_az

  # Create a mock that returns gateway timeout error
  cat > "${MOCK_AZ_PATH}" << 'EOF'
#!/bin/bash
echo "Error: GatewayTimeout (504)" >&2
exit 1
EOF
  chmod +x "${MOCK_AZ_PATH}"

  run retry_azure_operation 2 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Gateway timeout (504)"* ]]
  [[ "${output}" == *"Retrying"* ]]
}

@test "retry_azure_operation: identifies conflict errors" {
  create_mock_az

  # Create a mock that returns conflict error
  cat > "${MOCK_AZ_PATH}" << 'EOF'
#!/bin/bash
echo "Error: Conflict (409)" >&2
exit 1
EOF
  chmod +x "${MOCK_AZ_PATH}"

  run retry_azure_operation 2 "Test operation" az resource list

  [ "$status" -eq 1 ]
  [[ "${output}" == *"Conflict (409)"* ]]
  [[ "${output}" == *"Retrying"* ]]
}

@test "retry_azure_operation: exponential backoff increases delay" {
  create_mock_az
  export AZ_MOCK_BEHAVIOR="always_fail"
  export RETRY_BASE_DELAY=1

  run retry_azure_operation 3 "Test operation" az resource list

  [ "$status" -eq 1 ]
  # Should mention retrying with increasing delays (1s, 2s)
  [[ "${output}" == *"Retrying in 1s"* ]]
  [[ "${output}" == *"Retrying in 2s"* ]]
}
