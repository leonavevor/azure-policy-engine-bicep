// Perpose: Assign policy or policy initiative (built-in or custom) at either management group 
targetScope = 'managementGroup'

@sys.description('The policy or initiative definition ID to assign.')
param policyDefinitionId string

@sys.description('Assignment name of the policy or initiative assignment.')
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

// Assign the policy or initiative
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: assignmentName
  // use function to set the scope dynamically
  //scope: managementGroup(tenantResourceId('Microsoft.Management/managementGroups', targetManagementGroupId))
  properties: {
    displayName: empty(assignmentDisplayName) ? last(split(policyDefinitionId, '/')) : assignmentDisplayName
    description: empty(assignmentDescription)
      ? 'Assignment for policy/initiative: ${last(split(policyDefinitionId, '/'))}'
      : assignmentDescription
    enforcementMode: enforcementMode
    policyDefinitionId: policyDefinitionId
    parameters: assignmentParameters
    notScopes: [] // Optional: specify any exclusion scopes here
    nonComplianceMessages: [] // Optional: specify any non-compliance messages here
    overrides: null // Optional: specify any overrides here
    // resourceSelectors: // TODO: implement resource selectors for finer control over assignment scope in the future
  }
}
