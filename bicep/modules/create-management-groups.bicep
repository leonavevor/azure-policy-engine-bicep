targetScope = 'tenant'

metadata description = 'This module creates management groups as specified in the input parameters.'

param createManagementGroups bool = false
param managementGroupsToCreate array = []
param parentManagementGroupId string = 'mg-landing-zones'

// Create management groups if specified
resource _managementGroups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for mgName in managementGroupsToCreate: if (createManagementGroups) {
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
