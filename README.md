# Path access allowances for Calico with Kubernetes

## felix

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1                 |   R    |       |
| /calico/felix/v1           |   RW   |   Felix writes out stats    |

## calico/node

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1                 |   RW   |  Writes out default config, host IP config, libnetwork-plugin writes out WEPs and default policy    |
| /calico/felix/v1           |   RW   |  Felix writes out stats     |
| /calico/v1/ipam            |   RW   |  Creates default IP pools     |
| /calico/ipam/v2            |   RW   |  Allocates IP address for tunl0     |
| /calico/bgp/v1             |   RW   |  Creates default BGP config, and per-node BGP config     |

## cni

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1/host            |   RW   |  Writes out WEPs     |
| /calico/v1/policy          |   RW   |  Writes out default policy     |
| /calico/ipam/v2            |   RW   |  Allocates IP addresses / If using calico IPAM    |


## policy-controller

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1/host            |   RW   |  Writes out WEPs     |
| /calico/v1/policy          |   RW   |  Writes out default policy     |

## calicoctl (read only access)

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1                 |   R    |  Read BGP config, WEPs, Policy    |
| /calico/v1/ipam            |   R    |  Read IP pools     |
| /calico/ipam/v2            |   R    |  Read IP assignment     |
| /calico/bgp/v1             |   R    |  Read Node and BGP config     |

## calicoctl (read access for node/config/ips/weps/heps and read/write policy)

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1                 |   R    |  Read BGP config, WEPs    |
| /calico/v1/policy          |   RW   |  Read/Write policy   |
| /calico/v1/ipam            |   R    |  Read IP pools     |
| /calico/ipam/v2            |   R    |  Read IP assignment     |
| /calico/bgp/v1             |   R    |  Read Node and BGP config     |

## calicoctl (full read/write access)

| Path                       | Access | Notes |
|----------------------------|--------|-------|
| /calico/v1                 |   RW   |  Read/write BGP config, WEPs, Policy    |
| /calico/v1/ipam            |   RW   |  Read/write IP pools     |
| /calico/ipam/v2            |   RW   |  Read/write IP assignment     |
| /calico/bgp/v1             |   RW   |  Read/write Node and BGP config     |

