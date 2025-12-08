targetScope = 'managementGroup'

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
param assignAllPolicyInitiatives bool = true


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

// Assign all initiatives (built-in and custom) 
module _policyAssignmentsMgLevel './modules/deploy-policy-assignment.bicep' = [
  for initiativeModule in concat(builtInInitiatives, customPolicyInitiatives): if (assigmentMode == 'in-main' && assignAllPolicyInitiatives) {
    name: 'policy-assignment-${initiativeModule.name}'
    params: {
      policyDefinitionId: initiativeModule.outputs.initiativeId
      assignmentName: '${initiativeModule.outputs.initiativeName}-assignment'
      assignmentDisplayName: initiativeModule.outputs.displayName
      assignmentDescription: initiativeModule.outputs.description
      enforcementMode: 'Default'
      assignmentParameters: initiativeModule.outputs.assignmentParameters
    }
    dependsOn: [
      _customPolicyDefinitions
      _customPolicyInitiatives
    ]

    // scope: managementGroup(targetManagementGroupId)
    // scope: subscription()
  }
]

// TODO: Find a way to output array of initiative IDs from modules
//output customPolicyInitiativeId string = _customPolicyInitiatives[0].outputs.initiativeId
