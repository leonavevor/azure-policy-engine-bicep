targetScope = 'managementGroup'

//@description('The target management group name where the policies will be assigned. This overrides the default management group of the deployment context, if specified via the targetManagementGroupName parameter.')
//param managementGroupName string = managementGroup().name

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

@description('The target management group name where the policies will be assigned. This overrides the default management group of the deployment context, if specified via the targetManagementGroupName parameter.')
param parentManagementGroupName string = 'mg-landing-zones'

@description('Parameter to control where the policy initiatives are assigned from this main bicep file.')
param managementGroupNamesToCreate array = ['mg-confidential-corp', 'mg-confidential-online']

@description('Parameter to control whether to create management groups as specified in the input parameters.')
param creatManagementGroups bool = true

// Create management group (if not exists)
module _managementGroups './modules/create-management-groups.bicep' = if (creatManagementGroups) {
  scope: tenant()
  name: 'create-management-groups'
  params: {
    createManagementGroups: creatManagementGroups
    managementGroupsToCreate: managementGroupNamesToCreate
    parentManagementGroupId: parentManagementGroupName
  }
}

@description('Deploy custom policy definitions 1st, since custom initiatives may depend on them')
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

@description('Deploy custom initiatives 2nd, since they depend (i.e reference IDs of custom policy definitions or built-in initiatives) on custom policy definitions')
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

@description('Assign custom initiatives at management group level from main bicep file')
module _customPolicyInitiativeAssignments './modules/deploy-policy-assignment.bicep' = [
  for index in range(0, length(customPolicyInitiatives)): if (assignmentMode == 'in-main' && assignCustomPolicyInitiatives) {
    name: 'policy-assignment-${_customPolicyInitiatives[index].name}'
    params: {
      policyDefinitionId: _customPolicyInitiatives[index].outputs.?initiativeId
      assignmentName: _customPolicyInitiatives[index].outputs.?initiativeName
      assignmentDisplayName: _customPolicyInitiatives[index].outputs.?displayName ?? _customPolicyInitiatives[index].outputs.?initiativeName ?? ''
      assignmentDescription: _customPolicyInitiatives[index].outputs.?description ?? ''
      enforcementMode: _customPolicyInitiatives[index].outputs.?enforcementMode ?? 'Default'
      assignmentParameters: customPolicyInitiatives[index].?assignmentParameters ?? {}
      nonComplianceMessages: customPolicyInitiatives[index].?nonComplianceMessages ?? []
      notScopes: customPolicyInitiatives[index].?notScopes ?? []
      overrides: customPolicyInitiatives[index].?overrides ?? []
      resourceSelectors: customPolicyInitiatives[index].?resourceSelectors ?? []
    }
    dependsOn: [
      _customPolicyDefinitions
      _customPolicyInitiatives[index]
    ]

    //scope: map(range(0, length(managementGroupNamesToCreate)), i => managementGroup(managementGroupNamesToCreate[i]))[0]
    scope: managementGroup(managementGroup().name)
  }
]

@description('Assign built-in initiatives at management group level from main bicep file')
module _builtInPolicyInitiativeAssignments './modules/deploy-policy-assignment.bicep' = [
  for initiative in builtInInitiatives: if (assignmentMode == 'in-main' && assignBuiltInPolicyInitiatives) {
    name: 'policy-assignment-${initiative.initiativeName}'
    params: {
      policyDefinitionId: initiative.?policyDefinitionId
      assignmentName: take(replace(initiative.?initiativeName, '-', ''), 24) ?? take(
        uniqueString(deployment().name, initiative.initiativeName),
        24
      )
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
      //_customPolicyInitiativeAssignments
    ]

    //scope: map(range(0, length(managementGroupNamesToCreate)), i => managementGroup(managementGroupNamesToCreate[i]))[0]
    scope: managementGroup(managementGroup().name)
  }
]
