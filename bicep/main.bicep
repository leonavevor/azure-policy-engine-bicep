targetScope = 'managementGroup'

@description('The target management group name where the policies will be assigned. This overrides the default management group of the deployment context, if specified via the targetManagementGroupName parameter.')
param targetManagementGroupName string = managementGroup().name

@description('Parameter to control where the policy initiatives are assigned from this main bicep file.')
@allowed([
  'in-main'
  'in-modules'
])
param assigmentMode string = 'in-main'

// workaround hardcore in the filenames via parameters file one by one which is not ideal but works for now. 
// or run a script to consolidate all file contents (base on category), use it to create/update parameter files, then run bicep deployment
// ref: https://github.com/Azure/ALZ-Bicep/blob/main/infra-as-code/bicep/modules/policy/definitions/customPolicyDefinitions.bicep
param builtInInitiatives object[] = []
param customPolicyDefinitions object[] = []
param customPolicyInitiatives object[] = []

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
      assignmentMode: assigmentMode
      initiative: initiative
    }
    dependsOn: [
      _customPolicyDefinitions
    ]
  }
]

// Assign policy initiatives at management group level from main bicep file
module _customPolicyAssignmentsMgLevel './modules/deploy-policy-assignment.bicep' = [
  for index in range(0, length(customPolicyInitiatives)): if (assigmentMode == 'in-main' && assignCustomPolicyInitiatives) {
    name: 'policy-assignment-${_customPolicyInitiatives[index].name}'
    params: {
      policyDefinitionId: _customPolicyInitiatives[index].outputs.?initiativeId ?? fail('Initiative ID not found')
      assignmentName: _customPolicyInitiatives[index].outputs.?initiativeName ?? fail('Initiative name not found')
      assignmentDisplayName: _customPolicyInitiatives[index].outputs.?displayName ?? fail('Display name not found')
      assignmentDescription: _customPolicyInitiatives[index].outputs.?description ?? fail('Description not found')
      enforcementMode: 'Default'
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
module _builtInPolicyAssignmentsMgLevel './modules/deploy-policy-assignment.bicep' = [
  for initiative in builtInInitiatives: if (assigmentMode == 'in-main' && assignBuiltInPolicyInitiatives) {
    name: 'policy-assignment-${initiative.initiativeName}'
    params: {
      policyDefinitionId: initiative.?policyDefinitionId ?? fail('Policy Definition ID not found')
      assignmentName: initiative.?initiativeName ?? fail('Initiative name not found')
      assignmentDisplayName: initiative.initiativeName ?? fail('Display name not found')
      assignmentDescription: initiative.?description ?? fail('Description not found')
      enforcementMode: 'Default'
      assignmentParameters: initiative.?parameters ?? {}
    }

    dependsOn: [
      _customPolicyDefinitions
      _customPolicyAssignmentsMgLevel
    ]

    scope: managementGroup(targetManagementGroupName)
  }
]

// TODO: Find a way to output array of initiative IDs from modules
//output customPolicyInitiativeId string = _customPolicyInitiatives[0].outputs.initiativeId
//output out_customPolicyInitiatives object = toObject(_customPolicyInitiatives, entry => entry.outputs)
