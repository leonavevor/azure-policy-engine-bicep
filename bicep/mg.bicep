targetScope = 'managementGroup'

@description('The target management group name where the policies will be assigned. This overrides the default management group of the deployment context, if specified via the targetManagementGroupName parameter.')
param parentManagementGroupName string = 'mg-landing-zones'

@description('Parameter to control where the policy initiatives are assigned from this main bicep file.')
param managementGroupNamesToCreate array = ['mg-confidential-corp', 'mg-confidential-online']

@description('Parameter to control whether to create management groups as specified in the input parameters.')
param creatManagementGroups bool = true

// Create management group
module _managementGroups './modules/create-management-groups.bicep' = if (creatManagementGroups) {
  scope: tenant()
  name: 'create-management-groups'
  params: {
    createManagementGroups: creatManagementGroups
    managementGroupsToCreate: managementGroupNamesToCreate
    parentManagementGroupId: parentManagementGroupName
  }
}
