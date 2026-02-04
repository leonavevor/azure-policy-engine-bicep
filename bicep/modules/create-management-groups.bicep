targetScope = 'tenant'

metadata description = 'This module creates management groups as specified in the input parameters.'
metadata NOTE = 'Ensure that the deployment has the necessary permissions (owner when running from az cli bicep or ARM template deployment but not required when doing it from the portal) to create management groups in the tenant. ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-tenant?wt.mc_id=knowledgesearch_inproduct_azure-agent-for-github-copilot&tabs=azure-cli#required-access'

param createManagementGroups bool = true
// Accept an array of objects so each management group can optionally specify its parent for nested creation.
// Example item: { name: 'mg-child', displayName: 'MG Child', parent: 'mg-parent' }
param managementGroupsToCreate array = [
  {
    name: 'mg-corp'
    displayName: 'mg-corp'
    parent: 'mg-landing-zones'
  }
  {
    name: 'mg-online'
    displayName: 'mg-online'
    parent: 'mg-landing-zones'
  }
]
param parentManagementGroupId string = 'mg-landing-zones'

// Normalize input so every item has name, displayName and parent (falls back to parentManagementGroupId when omitted)
var normalizedMgs = [ for mg in managementGroupsToCreate: {
  name: mg.name
  displayName: mg.?displayName ?? mg.name
  // If caller provides full resource id (starts with /providers/) use it; otherwise build the managementGroup resourceId
  parentId: (mg.?parent != null && mg.?parent != '') ? (startsWith(mg.?parent, '/providers/') ? mg.?parent : resourceId('Microsoft.Management/managementGroups', mg.?parent)) : resourceId('Microsoft.Management/managementGroups', parentManagementGroupId)
}]

// Create management groups if specified
resource _managementGroups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for mg in normalizedMgs: if (createManagementGroups) {
    name: mg.name
    properties: {
      displayName: mg.displayName
      details: {
        parent: {
          id: mg.parentId
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

output outMgs mgsOutputTypeArray = [ for i in range(0, length(normalizedMgs)): {
  name: _managementGroups[i].name
  id: _managementGroups[i].id
  properties: _managementGroups[i].?properties
} ]
  
output outManagementGroups object[] = [
  for mg in normalizedMgs: {
    name: mg.name
    parentId: mg.parentId
  }
]
