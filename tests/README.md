# Shared Azure Health - Tests

This directory contains BATS (Bash Automated Testing System) tests for the shared-azure-health repository.

## Test Files

### `retry-utils.bats`
Tests for the `scripts/retry-utils.sh` retry utilities:
- Successful operations
- Transient failures with retry
- Permanent failures (no retry)
- Scope locked errors
- Max retry attempts
- Exponential backoff
- Error type identification

### `workflow-validation.bats`
Tests for the reusable `destroy-infrastructure.yml` workflow:
- Workflow structure validation
- Required inputs and secrets
- Azure authentication setup
- Tag-based filtering logic
- Retry mechanism integration
- Permissions configuration

### `examples.bats`
Tests for example workflow files:
- All example files exist
- Correct project names
- Proper workflow references
- Valid YAML syntax
- Required secrets passed
- Proper permissions set

## Running Tests

### Prerequisites

Install BATS:
```bash
# Ubuntu/Debian
sudo apt-get install bats

# macOS
brew install bats-core

# Or via npm
npm install -g bats
```

### Run All Tests

```bash
bats tests/
```

### Run Specific Test File

```bash
bats tests/retry-utils.bats
bats tests/workflow-validation.bats
bats tests/examples.bats
```

### Run with TAP Output

```bash
bats --tap tests/
```

### Run with Pretty Format

```bash
bats --pretty tests/
```

## Test Coverage

- **28 tests total**
  - 15 tests for retry utilities
  - 18 tests for workflow validation
  - 13 tests for example files

## CI Integration

These tests can be run in GitHub Actions:

```yaml
- name: Run BATS tests
  run: |
    sudo apt-get update && sudo apt-get install -y bats
    bats tests/
```

## Writing New Tests

Follow the BATS syntax:

```bash
@test "descriptive test name" {
  run command_to_test
  [ "$status" -eq 0 ]
  [[ "${output}" == *"expected text"* ]]
}
```

See existing test files for examples of:
- Setting up test fixtures
- Mocking Azure CLI commands
- Testing retry behavior
- Validating YAML structure
