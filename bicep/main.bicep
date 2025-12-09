targetScope = 'managementGroup'

@description('The target management group name where the policies will be assigned. This overrides the default management group of the deployment context, if specified via the targetManagementGroupName parameter.')
param targetManagementGroupName string = managementGroup().name

@description('Parameter to control where the policy initiatives are assigned from this main bicep file.')
@allowed([
  'in-main'
  'in-modules'
])
param assignmentMode string = 'in-main'

// workaround hardcore in the filenames via parameters file one by one which is not ideal but works for now. 
// or run a script to consolidate all file contents (base on category), use it to create/update parameter files, then run bicep deployment
// ref: https://github.com/Azure/ALZ-Bicep/blob/main/infra-as-code/bicep/modules/policy/definitions/customPolicyDefinitions.bicep
param customPolicyDefinitions object[] = []
param customPolicyInitiatives object[] = []
param builtInInitiatives object[] = []

param deployCustomPolicyDefinitions bool = true
param deployCustomPolicyInitiatives bool = true
param assignCustomPolicyInitiatives bool = true
param assignBuiltInPolicyInitiatives bool = true

// Deploy custom policy definitions 1st, since custom initiatives may depend on them
module _customPolicyDefinitions './modules/deploy-custom-policy-definition.bicep' = [
  for customPolicyDefinition in customPolicyDefinitions: if (deployCustomPolicyDefinitions) {
    name: 'policy-definition-${uniqueString(deployment().name, customPolicyDefinition.name)}'
    params: {
      name: customPolicyDefinition.name
      description: customPolicyDefinition.description
      displayName: customPolicyDefinition.displayName
      mode: customPolicyDefinition.mode
      metadata: customPolicyDefinition.metadata
      parameters: customPolicyDefinition.parameters
      policyRule: customPolicyDefinition.policyRule
    }
  }
]

// Deploy custom initiatives 2nd, since they depend (i.e reference IDs of custom policy definitions or built-in initiatives) on custom policy definitions
module _customPolicyInitiatives './modules/deploy-custom-initiative.bicep' = [
  for initiative in customPolicyInitiatives: if (deployCustomPolicyInitiatives) {
    name: 'custom-policy-initiative-${uniqueString(deployment().name, initiative.name)}'
    params: {
      assignmentMode: assignmentMode
      initiative: initiative
    }
    dependsOn: [
      _customPolicyDefinitions
    ]
  }
]

// Assign policy initiatives at management group level from main bicep file
module _customPolicyInitiativeAssignments './modules/deploy-policy-assignment.bicep' = [
  for index in range(0, length(customPolicyInitiatives)): if (assignmentMode == 'in-main' && assignCustomPolicyInitiatives) {
    name: 'policy-assignment-${_customPolicyInitiatives[index].name}'
    params: {
      policyDefinitionId: _customPolicyInitiatives[index].outputs.?initiativeId
      assignmentName: _customPolicyInitiatives[index].outputs.?initiativeName
      assignmentDisplayName: _customPolicyInitiatives[index].outputs.?displayName ?? _customPolicyInitiatives[index].outputs.?initiativeName ?? ''
      assignmentDescription: _customPolicyInitiatives[index].outputs.?description ?? ''
      enforcementMode: _customPolicyInitiatives[index].outputs.?enforcementMode ?? 'Default'
      assignmentParameters: _customPolicyInitiatives[index].outputs.?parameters ?? {}
    }
    dependsOn: [
      _customPolicyDefinitions
      _customPolicyInitiatives[index]
    ]

    scope: managementGroup(targetManagementGroupName)
  }
]

// Assign built-in policy initiatives at management group level from main bicep file
module _builtInPolicyInitiativeAssignments './modules/deploy-policy-assignment.bicep' = [
  for initiative in builtInInitiatives: if (assignmentMode == 'in-main' && assignBuiltInPolicyInitiatives) {
    name: 'policy-assignment-${initiative.initiativeName}'
    params: {
      policyDefinitionId: initiative.?policyDefinitionId 
      assignmentName: take(replace(initiative.?initiativeName, '-', ''), 24) ?? take(uniqueString(deployment().name, initiative.initiativeName), 24)
      assignmentDisplayName: initiative.displayName ?? initiative.initiativeName ?? '' 
      assignmentDescription: initiative.?description ?? ''
      enforcementMode: initiative.?enforcementMode ?? 'Default'
      assignmentParameters: initiative.?parameters ?? {}
      nonComplianceMessages: initiative.?nonComplianceMessages ?? []
      notScopes: initiative.?notScopes ?? []
      overrides: initiative.?overrides ?? []
      resourceSelectors: initiative.?resourceSelectors ?? []
    }

    dependsOn: [
      _customPolicyDefinitions
      _customPolicyInitiativeAssignments
    ]

    scope: managementGroup(targetManagementGroupName)
  }
]

// TODO: Find a way to output array of initiative IDs from modules
//output customPolicyInitiativeId string = _customPolicyInitiatives[0].outputs.initiativeId
//output out_customPolicyInitiatives object = toObject(_customPolicyInitiatives, entry => entry.outputs)
