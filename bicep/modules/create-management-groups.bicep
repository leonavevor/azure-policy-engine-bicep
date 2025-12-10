targetScope = 'tenant'

metadata description = 'This module creates management groups as specified in the input parameters.'
metadata NOTE = 'Ensure that the deployment has the necessary permissions (owner when running from az cli bicep or ARM template deployment but not required when doing it from the portal) to create management groups in the tenant. ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-tenant?wt.mc_id=knowledgesearch_inproduct_azure-agent-for-github-copilot&tabs=azure-cli#required-access'

param createManagementGroups bool = true
param managementGroupsToCreate array = ['mg-confidential-corp', 'mg-confidential-online']
param parentManagementGroupId string = 'mg-landing-zones'


// Create management groups if specified
resource _managementGroups 'Microsoft.Management/managementGroups@2024-02-01-preview' = [
  for mgName in managementGroupsToCreate: if (createManagementGroups) {
    //scope: managementGroup(parentManagementGroupId)
    name: 'management-groups-${mgName}'
    properties: {
      displayName: mgName
      details: {
        parent: {
          id: parentManagementGroupId
        }
      }
    }
  }
]

@sealed()
type mgsOutputType = {
  name: string
  id: string
  properties: object
}
type mgsOutputTypeArray = mgsOutputType[]

output outMgs mgsOutputTypeArray = [ for mg in range(0, length(managementGroupsToCreate)): {
  name: _managementGroups[mg].name
  id: _managementGroups[mg].id
  properties: _managementGroups[mg].?properties
} ]
  
output outManagementGroups object[] = [
  for mg in managementGroupsToCreate: {
    name: mg
  }
]
