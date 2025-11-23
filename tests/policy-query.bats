#!/usr/bin/env bats
# Tests for policy query utilities
# Run with: bats tests/policy-query.bats

# shellcheck disable=SC1091
source "${BATS_TEST_DIRNAME}/../scripts/policy-query.sh"

setup() {
  # Create temporary directory for mock scripts
  export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCK_DIR"
  export PATH="$MOCK_DIR:$PATH"
}

teardown() {
  # Clean up mocks
  rm -rf "$MOCK_DIR"
}

# Test: get_policy_assignments with valid resource group
@test "get_policy_assignments returns assignments for resource group" {
  # Mock az command
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy assignment list"* ]]; then
  echo '[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_assignments "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"assignment1"* ]]
  [[ "$output" == *"Test Assignment"* ]]
}

# Test: get_policy_assignments with no assignments
@test "get_policy_assignments returns empty array when no assignments" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
echo "[]"
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_assignments "test-rg"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# Test: get_policy_assignments without resource group parameter
@test "get_policy_assignments fails without resource group" {
  run get_policy_assignments
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Resource group name is required"* ]]
}

# Test: get_policy_assignments_with_compliance with compliant state
@test "get_policy_assignments_with_compliance returns assignments with compliance state" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy assignment list"* ]]; then
  echo '[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default","policyDefinitionId":"/subscriptions/test/providers/Microsoft.Authorization/policyDefinitions/test-policy"}]'
elif [[ "$*" == *"policy state list"* ]]; then
  echo '[{"policyAssignment":"assignment1","compliance":"Compliant"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  # Mock jq as it's needed for the function
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  run get_policy_assignments_with_compliance "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"assignment1"* ]]
  [[ "$output" == *"Compliant"* ]]
}

# Test: get_policy_assignments_with_compliance with non-compliant state
@test "get_policy_assignments_with_compliance shows non-compliant state" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy assignment list"* ]]; then
  echo '[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default","policyDefinitionId":"/subscriptions/test/providers/Microsoft.Authorization/policyDefinitions/test-policy"}]'
elif [[ "$*" == *"policy state list"* ]]; then
  echo '[{"policyAssignment":"assignment1","compliance":"NonCompliant"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  run get_policy_assignments_with_compliance "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NonCompliant"* ]]
}

# Test: get_policy_exemptions with valid exemptions
@test "get_policy_exemptions returns exemptions for resource group" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy exemption list"* ]]; then
  echo '[{"name":"exemption1","displayName":"Test Exemption","exemptionCategory":"Waiver","expiresOn":"2025-12-31"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_exemptions "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exemption1"* ]]
  [[ "$output" == *"Test Exemption"* ]]
  [[ "$output" == *"Waiver"* ]]
}

# Test: get_policy_exemptions with no exemptions
@test "get_policy_exemptions returns empty array when no exemptions" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
echo "[]"
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_exemptions "test-rg"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# Test: get_policy_exemptions without resource group
@test "get_policy_exemptions fails without resource group" {
  run get_policy_exemptions
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Resource group name is required"* ]]
}

# Test: format_policy_assignments with single compliant assignment
@test "format_policy_assignments formats single compliant assignment" {
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  local json='[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default","complianceState":"Compliant"}]'
  run format_policy_assignments "$json" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Assignments (1):"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"**Test Assignment**"* ]]
  [[ "$output" == *"_Compliant_"* ]]
}

# Test: format_policy_assignments with multiple assignments
@test "format_policy_assignments handles multiple assignments" {
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  local json='[
    {"name":"assignment1","displayName":"Assignment One","enforcementMode":"Default","complianceState":"NonCompliant"},
    {"name":"assignment2","displayName":"Assignment Two","enforcementMode":"DoNotEnforce","complianceState":"Compliant"}
  ]'
  run format_policy_assignments "$json" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Assignments (2):"* ]]
  [[ "$output" == *"❌"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"**Assignment One**"* ]]
  [[ "$output" == *"**Assignment Two**"* ]]
}

# Test: format_policy_assignments with empty array
@test "format_policy_assignments handles empty array" {
  run format_policy_assignments "[]" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No policy assignments found"* ]]
}

# Test: format_policy_assignments with null/empty input
@test "format_policy_assignments handles null input" {
  run format_policy_assignments "" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No policy assignments found"* ]]
}

# Test: format_policy_exemptions with single exemption
@test "format_policy_exemptions formats single exemption with expiration" {
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  local json='[{"name":"exemption1","displayName":"Test Exemption","exemptionCategory":"Waiver","expiresOn":"2025-12-31","policyAssignmentId":"/subscriptions/test/resourceGroups/test/providers/Microsoft.Authorization/policyAssignments/test-policy","description":"Test reason"}]'
  run format_policy_exemptions "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Exemptions (1):"* ]]
  [[ "$output" == *"🛡️ **Test Exemption** - _Waiver_"* ]]
  [[ "$output" == *"**Expires:** 2025-12-31"* ]]
  [[ "$output" == *"**Reason:** Test reason"* ]]
  [[ "$output" == *"**Policy:** \`test-policy\`"* ]]
}

# Test: format_policy_exemptions without expiration date
@test "format_policy_exemptions handles exemptions without expiration" {
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  local json='[{"name":"exemption1","displayName":"Permanent Exemption","exemptionCategory":"Mitigated","policyAssignmentId":"/subscriptions/test/resourceGroups/test/providers/Microsoft.Authorization/policyAssignments/test-policy","description":"Test reason"}]'
  run format_policy_exemptions "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"🛡️ **Permanent Exemption** - _Mitigated_"* ]]
  [[ "$output" != *"**Expires:**"* ]]
  [[ "$output" == *"**Reason:** Test reason"* ]]
}

# Test: format_policy_exemptions with empty array
@test "format_policy_exemptions handles empty array" {
  run format_policy_exemptions "[]"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No policy exemptions found"* ]]
}

# Test: format_policy_exemptions with multiple exemptions
@test "format_policy_exemptions handles multiple exemptions" {
  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  local json='[
    {"name":"ex1","displayName":"Exemption One","exemptionCategory":"Waiver","expiresOn":"2025-12-31","policyAssignmentId":"/subscriptions/test/resourceGroups/test/providers/Microsoft.Authorization/policyAssignments/policy-one","description":"Reason one"},
    {"name":"ex2","displayName":"Exemption Two","exemptionCategory":"Mitigated","policyAssignmentId":"/subscriptions/test/resourceGroups/test/providers/Microsoft.Authorization/policyAssignments/policy-two","description":"Reason two"}
  ]'
  run format_policy_exemptions "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Exemptions (2):"* ]]
  [[ "$output" == *"🛡️ **Exemption One** - _Waiver_"* ]]
  [[ "$output" == *"🛡️ **Exemption Two** - _Mitigated_"* ]]
  [[ "$output" == *"**Reason:** Reason one"* ]]
  [[ "$output" == *"**Reason:** Reason two"* ]]
}

# Test: generate_policy_report complete workflow
@test "generate_policy_report creates complete formatted report" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy assignment list"* ]]; then
  echo '[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default","policyDefinitionId":"/subscriptions/test/providers/Microsoft.Authorization/policyDefinitions/test-policy"}]'
elif [[ "$*" == *"policy state list"* ]]; then
  echo '[{"policyAssignment":"assignment1","compliance":"Compliant"}]'
elif [[ "$*" == *"policy exemption list"* ]]; then
  echo '[{"name":"exemption1","displayName":"Test Exemption","exemptionCategory":"Waiver","policyAssignmentId":"/subscriptions/test/resourceGroups/test/providers/Microsoft.Authorization/policyAssignments/test-policy","description":"Test reason"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  run generate_policy_report "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Azure Policy Status"* ]]
  [[ "$output" == *"Policy Assignments (1):"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"**Test Assignment**"* ]]
  [[ "$output" == *"Policy Exemptions (1):"* ]]
  [[ "$output" == *"🛡️ **Test Exemption** - _Waiver_"* ]]
  [[ "$output" == *"**Reason:** Test reason"* ]]
}

# Test: generate_policy_report without resource group
@test "generate_policy_report fails without resource group" {
  run generate_policy_report
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Resource group name is required"* ]]
}

# Test: generate_policy_report with no policies or exemptions
@test "generate_policy_report handles resource group with no policies" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
echo "[]"
EOF
  chmod +x "$MOCK_DIR/az"

  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  run generate_policy_report "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Azure Policy Status"* ]]
  [[ "$output" == *"No policy assignments found"* ]]
  [[ "$output" == *"No policy exemptions found"* ]]
}

# Test: get_noncompliant_resources returns non-compliant resources
@test "get_noncompliant_resources returns filtered resources" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
echo '[
  {"resourceId":"/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/vm1","resourceType":"Microsoft.Compute/virtualMachines","resourceLocation":"eastus","policyAssignmentName":"test-assignment","complianceState":"NonCompliant"},
  {"resourceId":"/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/storage1","resourceType":"Microsoft.Storage/storageAccounts","resourceLocation":"westus","policyAssignmentName":"test-assignment","complianceState":"Compliant"}
]'
EOF
  chmod +x "$MOCK_DIR/az"

  cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
/usr/bin/jq "$@"
EOF
  chmod +x "$MOCK_DIR/jq"

  run get_noncompliant_resources "test-rg" "test-assignment"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vm1"* ]]
  [[ "$output" == *"Microsoft.Compute/virtualMachines"* ]]
  [[ "$output" != *"storage1"* ]]
}

# Test: get_policy_description retrieves policy description
@test "get_policy_description returns description from policy definition" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy definition show"* ]]; then
  echo "This is a test policy description"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  cat > "$MOCK_DIR/basename" << 'EOF'
#!/bin/bash
echo "test-policy"
EOF
  chmod +x "$MOCK_DIR/basename"

  run get_policy_description "/subscriptions/test/providers/Microsoft.Authorization/policyDefinitions/test-policy"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test policy description"* ]]
}
