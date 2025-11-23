#!/bin/bash

# Retry utilities for Azure operations
# Based on patterns from pwsh-azure-health and ts-azure-health

# retry_azure_operation - Retry an Azure CLI command with exponential backoff
#
# Usage: retry_azure_operation <max_attempts> <description> <command> [args...]
#
# Arguments:
#   max_attempts: Maximum number of retry attempts
#   description: Human-readable description of the operation
#   command: The Azure CLI command to execute
#   args: Additional arguments for the command
#
# Returns:
#   0 if the command succeeds
#   Non-zero if the command fails after all retries
#
# Environment Variables:
#   RETRY_BASE_DELAY: Base delay in seconds between retries (default: 2)
#
retry_azure_operation() {
  local max_attempts="$1"
  shift
  local description="$1"
  shift
  local command=("$@")

  local attempt=1
  local delay="${RETRY_BASE_DELAY:-2}"

  while [ $attempt -le "$max_attempts" ]; do
    echo "Attempt $attempt/$max_attempts: $description" >&2

    # Execute command and capture both output and exit code
    local output
    local exit_code
    output=$("${command[@]}" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
      echo "$output"
      return 0
    fi

    # Check for permanent failures (don't retry)
    if echo "$output" | grep -qE "(AuthorizationFailed|InvalidAuthenticationToken|Forbidden|InvalidResourceGroupName)"; then
      echo "❌ Permanent failure detected: $description" >&2
      echo "$output" >&2
      return $exit_code
    fi

    # Check for scope locked errors
    if echo "$output" | grep -qE "ScopeLocked"; then
      echo "❌ Resource is locked. Cannot delete while lock is in place." >&2
      echo "$output" >&2
      return $exit_code
    fi

    if [ $attempt -eq "$max_attempts" ]; then
      echo "❌ Failed after $max_attempts attempts: $description" >&2
      echo "$output" >&2
      return $exit_code
    fi

    # Identify error type for better logging
    local error_type="Unknown error"
    if echo "$output" | grep -qE "TooManyRequests|429"; then
      error_type="Rate limit (429)"
    elif echo "$output" | grep -qE "ServiceUnavailable|503"; then
      error_type="Service unavailable (503)"
    elif echo "$output" | grep -qE "GatewayTimeout|504"; then
      error_type="Gateway timeout (504)"
    elif echo "$output" | grep -qE "InternalServerError|500"; then
      error_type="Internal server error (500)"
    elif echo "$output" | grep -qE "Conflict|409"; then
      error_type="Conflict (409)"
    fi

    echo "⚠️ $error_type - Retrying in ${delay}s..." >&2
    # Show the actual error for debugging
    if [ "$error_type" = "Unknown error" ]; then
      echo "Error details:" >&2
      echo "$output" >&2
    fi
    sleep "$delay"

    # Exponential backoff (integer arithmetic only)
    delay=$((delay * 2))
    attempt=$((attempt + 1))
  done

  return 1
}

# Export function for use in other scripts
export -f retry_azure_operation
