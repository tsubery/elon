# Cancelling Bitcoin - Definitive How To guide
## TLDR
Bitcoin wastes immense amounts of energy. It's community is complicit with crime and uses divisive marketing tactics. This poses great risk of community backlash, using the described tools to create long running outages of Bitcoin's network and/or network splits that may cause transactions to be rolled back. Since no one wants to have their assets sieged at will by an angry mob, this situation jeopardizes Bitcoin's price.

## Into

Bitcoin does not have access control mechanism, this is touted as a feature, allowing anyone with internet access to participate in various ways. For example, submit & receive transactions or submit & receive information about the other participants in the network. The open nature of the network is in fact it's achilles heel because activists can flood the network with garbage information and consume resources without supporting the network. Every network and computer system has limited resources such as bandwidth, memory and computing power. In order to estimate the risk, we need to estimate the different capacities in the system and find the ones that are the easiest to overwhelm.

## Estimating network's capacity
The myth that Bitcoin's network has massive capacities relies on misunderstanding of the technology. The network is comprised of three different nodes which contribute and consume different resources to the network.

1. Full Nodes - These are distributed data stores backed by Level DB. They provide services of data query & propagation.
2. Wallet Nodes - These are typically short lived nodes, they do not store the full database of around 360GB at the time of writing. These nodes do not publish "NETWORK_NODE" bit to to inform other participants of their limited capacity. 
3. Miner Nodes - These nodes encompass the majority of resources of the network. Since mining is done in private these are not a target for crowd sourced attack and are irrelevant for the purpose of this article.

It is important to note that adding mining resources to bitcoin is rewarded by design while adding distributed database nodes is not rewarded at all. It should surprise no one that as mining network scaled, the resouces for the distributed database node have been starved of resources.

### Full-node resources
Many are aware of block size wars, where Bitcoin's development team chose to limit the resources needed from each full node in order to lower the barriers for entry for full nodes. There are other limitations in the reference full node implemenation. Limiting node's capacity makes each node vulnerable to various denial of services attacks. Some of the [capacities](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h) of Full Nodes are:
1. Networking
   1. [125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L72) simultanous peer connections
   1. [11/125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L64-L68) Are for outgoing connections
   1. [1/125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L68) "Feeler" connection to test availability of new nodes
1. Address Manager
   1. 1024 "[buckets](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)" for storing information about new nodes 
   1. 256 "[buckets](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)" for storing information about nodes that had been reached
   1. 64 entries in each [bucket](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L133)
   2. Publicly accessible [services](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L288) attribute for each new node

Any of these limitations is subject to trivial attacks.

### How many full-nodes are out there?
We will write our own scanner further on, in the meantime you can look at [bitnodes.io](https://bitcoin.io) or [bitcoinstatus.net](http://bitcoinstatus.net). At the moment of writing, I can reach 5500 nodes that advertise themselves as full nodes using [NODE_NETWORK](https://github.com/bitcoin/bitcoin/blob/b34bf2b42caaee7c8714c1229e877128916d914a/src/protocol.h#L276) bit.
Bitnodes shows me 8500 because it considers nodes active if they are reachable in the recent past. You can try it yourself. The following command uses [bitnodes api](https://bitnodes.io/api/) to get the latest list of nodes, we parse it using ruby (must have it installed), then count how many have their "services" field on.
```bash
curl -H "Accept: application/json; indent=4" https://bitnodes.io/api/v1/snapshots/latest/ |\
  ruby -e 'require "json"; puts JSON.parse(ARGF.read())["nodes"].values.count{|a| a[3] % 2 == 1}'
````

