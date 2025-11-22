#!/usr/bin/env bats

# Integration tests for the destroy-infrastructure workflow
# These tests validate the workflow structure and inputs

setup() {
  export WORKFLOW_FILE="${BATS_TEST_DIRNAME}/../.github/workflows/destroy-infrastructure.yml"
}

@test "destroy workflow: file exists" {
  [ -f "${WORKFLOW_FILE}" ]
}

@test "destroy workflow: is valid YAML" {
  # Check if yamllint is available
  if command -v yamllint &> /dev/null; then
    run yamllint -d relaxed "${WORKFLOW_FILE}"
    [ "$status" -eq 0 ]
  else
    skip "yamllint not installed"
  fi
}

@test "destroy workflow: has workflow_call trigger" {
  run grep -q "workflow_call:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: requires project-name input" {
  run grep -A 2 "project-name:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"required: true"* ]]
}

@test "destroy workflow: requires environment input" {
  run grep -A 2 "environment:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"required: true"* ]]
}

@test "destroy workflow: requires resource-group input" {
  run grep -A 2 "resource-group:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"required: true"* ]]
}

@test "destroy workflow: requires AZURE_CLIENT_ID secret" {
  run grep -A 2 "AZURE_CLIENT_ID:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"required: true"* ]]
}

@test "destroy workflow: requires AZURE_TENANT_ID secret" {
  run grep -A 2 "AZURE_TENANT_ID:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"required: true"* ]]
}

@test "destroy workflow: requires AZURE_SUBSCRIPTION_ID secret" {
  run grep -A 2 "AZURE_SUBSCRIPTION_ID:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"required: true"* ]]
}

@test "destroy workflow: uses Azure login action" {
  run grep -q "azure/login@v2" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: uses tag-based filtering" {
  run grep -q "tags.project==" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: checks if resource group exists" {
  run grep -q "az group exists" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: uses retry utilities" {
  run grep -q "retry_azure_operation" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: sources retry-utils.sh" {
  run grep -q "source /tmp/retry-utils.sh" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: has proper permissions" {
  run grep -A 2 "permissions:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"id-token: write"* ]]
  [[ "${output}" == *"contents: read"* ]]
}

@test "destroy workflow: generates step summary" {
  run grep -q "GITHUB_STEP_SUMMARY" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: handles non-existent resource group" {
  run grep -q "steps.check_rg.outputs.exists == 'false'" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: sets MAX_RETRY_ATTEMPTS" {
  run grep -q "MAX_RETRY_ATTEMPTS:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}

@test "destroy workflow: sets RETRY_BASE_DELAY" {
  run grep -q "RETRY_BASE_DELAY:" "${WORKFLOW_FILE}"
  [ "$status" -eq 0 ]
}
