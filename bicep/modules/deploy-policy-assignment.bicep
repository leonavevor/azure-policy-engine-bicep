targetScope = 'managementGroup'

metadata Description = 'Module to assign a policy or policy initiative (built-in or custom)'


@sys.description('The policy or initiative definition ID to assign.')
param policyDefinitionId string

@sys.description('Assignment name of the policy or initiative assignment.')
@maxLength(24)
param assignmentName string

@sys.description('Display name used for the assignment when it is created. Defaults to the policy/initiative display name.')
param assignmentDisplayName string = ''

@sys.description('Description used for the assignment when it is created. Defaults to the policy/initiative description.')
param assignmentDescription string = ''

@sys.description('Enforcement mode used by the policy assignment.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@sys.description('Optional parameters that will be passed into the policy assignment.')
param assignmentParameters object = {}

@sys.description('Optional array of scopes that should be excluded from the policy assignment.')
param notScopes array = []

@sys.description('Optional array of non-compliance messages for the policy assignment.')
param nonComplianceMessages array = []

@sys.description('Optional overrides for the policy assignment.')
param overrides array = []

@sys.description('Optional array of resource selectors for the policy assignment.')
param resourceSelectors array = []


// Assign the policy or initiative (built-in or custom)
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: assignmentName
  properties: {
    displayName: empty(assignmentDisplayName) ? last(split(policyDefinitionId, '/')) : assignmentDisplayName
    description: empty(assignmentDescription)
      ? 'Assignment for policy/initiative: ${last(split(policyDefinitionId, '/'))}'
      : assignmentDescription
    enforcementMode: enforcementMode
    policyDefinitionId: policyDefinitionId
    parameters: assignmentParameters
    notScopes: notScopes 
    nonComplianceMessages: nonComplianceMessages 
    overrides: overrides
    resourceSelectors: resourceSelectors 
  }
}

output outPolicyAssignment object = policyAssignment
output assignmentId string = policyAssignment.id
output assignmentNameOutput string = policyAssignment.name
output assignmentDisplayNameOutput string = policyAssignment.properties.displayName
output assignmentDescriptionOutput string = policyAssignment.properties.description
output assignmentParametersOutput object = policyAssignment.properties.parameters
output assignmentEnforcementMode string = policyAssignment.properties.enforcementMode
output assignmentNotScopes array = policyAssignment.properties.notScopes
output assignmentNonComplianceMessages array = policyAssignment.properties.nonComplianceMessages
output assignmentOverrides array = policyAssignment.properties.overrides
output assignmentResourceSelectors array = policyAssignment.properties.resourceSelectors
