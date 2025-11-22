#!/usr/bin/env bats

# Tests for example workflow files
# Validates that example callers are correctly configured

setup() {
  export EXAMPLES_DIR="${BATS_TEST_DIRNAME}/../examples"
}

@test "examples: py-azure-health example exists" {
  [ -f "${EXAMPLES_DIR}/py-azure-health-destroy.yml" ]
}

@test "examples: pwsh-azure-health example exists" {
  [ -f "${EXAMPLES_DIR}/pwsh-azure-health-destroy.yml" ]
}

@test "examples: ts-azure-health example exists" {
  [ -f "${EXAMPLES_DIR}/ts-azure-health-destroy.yml" ]
}

@test "examples: py-azure-health uses correct project-name" {
  run grep "project-name: py-azure-health" "${EXAMPLES_DIR}/py-azure-health-destroy.yml"
  [ "$status" -eq 0 ]
}

@test "examples: pwsh-azure-health uses correct project-name" {
  run grep "project-name: pwsh-azure-health" "${EXAMPLES_DIR}/pwsh-azure-health-destroy.yml"
  [ "$status" -eq 0 ]
}

@test "examples: ts-azure-health uses correct project-name" {
  run grep "project-name: ts-azure-health" "${EXAMPLES_DIR}/ts-azure-health-destroy.yml"
  [ "$status" -eq 0 ]
}

@test "examples: py-azure-health calls shared workflow" {
  run grep "stuartshay/shared-azure-health/.github/workflows/destroy-infrastructure.yml@master" "${EXAMPLES_DIR}/py-azure-health-destroy.yml"
  [ "$status" -eq 0 ]
}

@test "examples: pwsh-azure-health calls shared workflow" {
  run grep "stuartshay/shared-azure-health/.github/workflows/destroy-infrastructure.yml@master" "${EXAMPLES_DIR}/pwsh-azure-health-destroy.yml"
  [ "$status" -eq 0 ]
}

@test "examples: ts-azure-health calls shared workflow" {
  run grep "stuartshay/shared-azure-health/.github/workflows/destroy-infrastructure.yml@master" "${EXAMPLES_DIR}/ts-azure-health-destroy.yml"
  [ "$status" -eq 0 ]
}

@test "examples: all examples are valid YAML" {
  # Check if yamllint is available
  if command -v yamllint &> /dev/null; then
    for file in "${EXAMPLES_DIR}"/*.yml; do
      run yamllint -d relaxed "${file}"
      [ "$status" -eq 0 ]
    done
  else
    skip "yamllint not installed"
  fi
}

@test "examples: all examples have workflow_dispatch trigger" {
  for file in "${EXAMPLES_DIR}"/*.yml; do
    run grep -q "workflow_dispatch:" "${file}"
    [ "$status" -eq 0 ]
  done
}

@test "examples: all examples pass secrets" {
  for file in "${EXAMPLES_DIR}"/*.yml; do
    run grep -q "AZURE_CLIENT_ID" "${file}"
    [ "$status" -eq 0 ]
    run grep -q "AZURE_TENANT_ID" "${file}"
    [ "$status" -eq 0 ]
    run grep -q "AZURE_SUBSCRIPTION_ID" "${file}"
    [ "$status" -eq 0 ]
  done
}

@test "examples: all examples have environment input" {
  for file in "${EXAMPLES_DIR}"/*.yml; do
    run grep -A 3 "environment:" "${file}"
    [ "$status" -eq 0 ]
  done
}

@test "examples: all examples have proper permissions" {
  for file in "${EXAMPLES_DIR}"/*.yml; do
    run grep -A 2 "permissions:" "${file}"
    [ "$status" -eq 0 ]
    [[ "${output}" == *"id-token: write"* ]]
    [[ "${output}" == *"contents: read"* ]]
  done
}
