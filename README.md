# Cancelling Bitcoin - Definitive How To guide
## TLDR
Bitcoin wastes immense amounts of energy and it's community is complicit with crime and uses divisive marketing tactics. This poses great risk of community backlash, creating long running outages of Bitcoin's network. Since no one wants to have their assets sieged at will by angry mobs, this situation jeopardizes Bitcoin's price.

## Into

Bitcoin does not have access control mechanism, this is touted as a feature, allowing anyone with internet access to participate in various ways. For example, submit & receive transactions or submit & receive information about the other participants in the network. The open nature of the network is in fact it's achilles heel because activists can flood the network with garbage information. Every network and computer system has limited resources such as bandwidth, memory and computing power. In order to estimate the risk, we need to estimate the different capacities in the system and find the ones that are the easiest to overwhelm.

## Estimating network's capacity
The myth that Bitcoin's network has massive capacities relies on misunderstanding of the technology. The network is comprised of three different nodes which contribute and consume different resources to the network.

1. Full Nodes - These are distributed data stores backed by Level DB. They provide services of data query & propagation.
2. Wallet Nodes - These are typically short lived nodes, they do not store the full database of around 360GB at the time of writing. These nodes do not publish "NETWORK_NODE" bit to to inform other participants of their limited capacity. 
3. Miner Nodes - These nodes encompass the majority of resources of the network. Since mining is done in private these are not a target for crowd sourced attack and are irrelevant for the purpose of this article.

It is important to note that adding mining resources to bitcoin is rewarded by design while adding distributed database nodes is not rewarded at all. It should surprise no one that as mining network scaled, the resouces for the distributed database node have been starved of resources.

### How many full-nodes are out there?
The habitual reach for google will unfortunately lead you astray. I will show you several ways to verify the actual number is overstated by a factor of 100-1000 times in most publications.
1. Open [bitnodes.io](https://bitcoin.io)
