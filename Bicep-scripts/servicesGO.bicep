@description('Location for all resources.')
param location string = resourceGroup().location

param vnetname string = 'theVNet'
param subnetName string = 'goservicesSubnet'
param dnsRecordName string ='serviceshostname'
param dnszonename string='thednszonename.dk'
param storageAccountName string='nostorage'

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: vnetname
  resource subnet 'subnets@2022-01-01' existing = {
    name: subnetName
  }
}

// --- Get a reference to the existing storage account ---
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

// --- Create the DevOps container group ---
@description('auktionsHuset services Container Group')
resource auktionsHusetDevOpsGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {

  name: 'auktionsHusetservicesGroup'
  location: location

  properties: {
    sku: 'Standard'

    containers: [
      {
        name: 'authservice'
        properties: {
          image: 'asbjorndev/auctions_authservice-image:1.0.0'
          ports: [
            {
              port: 3005
            }
          ]
          environmentVariables: [
            {
              name: 'Address'
              value: 'https://vaulthost:8201/'
            }
            {
              name: 'Token'
              value: '00000000-0000-0000-0000-000000000000'
            }
            {
              name: 'UserServiceUrl'
              value: 'http://userservice:8080'
            }
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
        }
      }
      {
        name: 'userservice'
        properties: {
          image: 'asbjorndev/auction_userservice-image:latest'
          ports: [
            {
              port: 3010
            }
          ]
          environmentVariables: [
            {
              name: 'Address'
              value: 'https://vaulthost:8201/'
            }
            {
              name: 'Token'
              value: '00000000-0000-0000-0000-000000000000'
            }
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
        }
      }
      {
        name: 'catalogservice'
        properties: {
          image: 'chilinhm/catalogservice-image:1.0.0'
          ports: [
            {
              port: 3015
            }
          ]
          environmentVariables: [
            {
              name: 'Address'
              value: 'https://vaulthost:8201/'
            }
            {
              name: 'Token'
              value: '00000000-0000-0000-0000-000000000000'
            }
            {
             name: 'loki'
             value: 'http://loki:3100'
            }
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
        }
      }
      {
        name: 'auctionservice'
        properties: {
          image: 'cptfaxe/auctionservice-image:1.0.0'
          ports: [
            {
              port: 3020
            }
          ]
          environmentVariables: [
            {
              name: 'Address'
              value: 'https://vaulthost:8201/'
            }
            {
              name: 'Token'
              value: '00000000-0000-0000-0000-000000000000'
            }
            {
             name: 'ConnectionURI'
             value: 'http://catalogservice:8080'
            }
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
        }
      }
      {
        name: 'biddingservice'
        properties: {
          image: 'jakobmagni/biddingservice-image:1.0.0'
          ports: [
            {
              port: 3025
            }
          ]
          environmentVariables: [
            {
              name: 'Address'
              value: 'https://vaulthost:8201/'
            }
            {
              name: 'Token'
              value: '00000000-0000-0000-0000-000000000000'
            }
            {
             name: 'auctionServiceUrl'
             value: 'http://auctionservice:8080'
            }
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
        }
      }
      {
        name: 'legalservice'
        properties: {
          image: 'asbjorndev/auctions_legalservice-image:latest'
          ports: [
            {
              port: 3030
            }
          ]
          environmentVariables: [
            {
              name: 'Address'
              value: 'https://vaulthost:8201/'
            }
            {
              name: 'Token'
              value: '00000000-0000-0000-0000-000000000000'
            }
            {
             name: 'AuctionServiceUrl'
             value: 'http://auctionservice:8080'
            }
            {
              name: 'UserServiceUrl'
              value: 'http://userservice:8080'
             }
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
        }
      } 
    ]
    initContainers: []
    restartPolicy: 'Always'
    ipAddress: {
      ports: [
        {
          port: 3005
        }
        {
          port: 3010
        }
        {
          port: 3015
        }
        {
          port: 3020
        }
        {
          port: 3025
        }
        {
          port: 3030
        }
      ]
      ip: '10.0.2.4'
      type: 'Private'
    }
    osType: 'Linux'
    subnetIds: [
      {
        id: VNET::subnet.id
      }
    ]
    dnsConfig: {
      nameServers: [
        '10.0.0.10'
        '10.0.0.11'
      ]
      searchDomains: dnszonename
    }
  }
}

// --- Get a reference to the existing DNS zone ---
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: dnszonename
}

// --- Create the DNS record for the DevOps container group ---
resource dnsRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: dnsRecordName
  parent: dnsZone
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: auktionsHusetDevOpsGroup.properties.ipAddress.ip
      }
    ]
  }
}

output containerIPAddressFqdn string = auktionsHusetDevOpsGroup.properties.ipAddress.ip