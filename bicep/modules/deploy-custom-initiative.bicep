// This Bicep file creates an initiative by loading custom initiative from a JSON file and assigns it to a management group.
targetScope = 'managementGroup'


@sys.description('Parameter to control where the policy initiative is assigned from this module.')
@allowed([
  'in-main'
  'in-modules'
])
param assignmentMode string
param initiative object

// Create the initiative
resource customPolicySetDefinition 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiative.name
  properties: {
    policyType: 'Custom'
    displayName: initiative.displayName
    description: initiative.description
    parameters: initiative.parameters ?? {}
    metadata: {
      category: initiative.metadata.category ?? 'azure-cloud'
      version: initiative.metadata.version ?? '1.0.0'
    }
    policyDefinitions: initiative.policyDefinitions
  }
}

// Assign the initiative
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = if (assignmentMode == 'in-modules') {
  name: '${initiative.name}-assignment'
  properties: {
    displayName: initiative.displayName
    description: initiative.description
    enforcementMode: 'Default'
    policyDefinitionId: customPolicySetDefinition.id
    parameters: initiative.assignmentParameters ?? {}
  }
}

output initiativeId string = customPolicySetDefinition.id
