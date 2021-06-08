# Cancelling Bitcoin - Definitive How To guide
## TLDR
Bitcoin wastes immense amounts of [energy](https://digiconomist.net/bitcoin-energy-consumption). It's community is complicit with crime and uses divisive marketing tactics. This poses great risk of backlash from the rest of society, using [Elon](https://github.com/tsubery/elon) to create long running outages of Bitcoin's network. This would render private wallets, where most of the "value" is stored, unusable for long periods at a time. When holders will realize access to their assets can be controlled by angry mobs they will be less inclined to use it as store of value. [Professionals](https://www.youtube.com/watch?v=pcToFASnyrc) are aware and have been warning about these issues. Hackers & Bitcoin salesepeople would like to keep the following information out of sight because it might kill their golden goose.

## Overview

Bitcoin's open nature is touted as a feature, In reality it makes it a sitting duck for various forms of attack. Current information about participants is availabe on [https://bitnodes.io] and [http://bitcoinstatus.net]. Because all the addresses are public, it's easy to see most of the nodes are hosted in data centers such as Amazon, Google, Microsoft, etc. It would be easy to point out the hypocracy of these companies providing services to support bitcoin while publicizing their [ESG goals](https://aws.amazon.com/blogs/enterprise-strategy/it-and-esg-part-two-how-it-can-and-must-further-the-companys-esg-efforts/) and buying [carbon credits](https://www.geekwire.com/2020/amazon-pledges-10m-forest-preservation-carbon-offsets-appalachians/). They have colluded in the past to kick [Parler](https://edition.cnn.com/2021/01/09/tech/parler-suspended-apple-app-store/index.html) and they can do that to bitcoin. 
Like any distributed computer system, Bitcoin has certain capacities that can be consumed by attackers in order to render services [unavailable](https://en.wikipedia.org/wiki/Denial-of-service_attack) to normal usage. As i will show, this is surprisingly easy to do because Bitcoin sofware has major flaws that I will describe in this article.

## Estimating networks capacity
The myth that Bitcoin's network has massive capacity relies on technical slight of hand. The network is comprised of three different nodes which contribute and consume different resources to the network.

1. Full Nodes - These are distributed data stores backed by [Level DB](https://github.com/bitcoin/bitcoin/tree/55a156fca08713b020aafef91f40df8ce4bc3cae/src/leveldb). They provide services of data query & propagation.
2. Wallet Nodes - These are typically short lived nodes, they do not store the full database of around 360GB at the time of writing. These nodes do not publish "NETWORK_NODE" bit to to inform other participants of their limited capacity. 
3. Miner Nodes - These nodes encompass the majority of resources of the network. Since mining is done in private these are not a target for crowd sourced attack and are irrelevant for the purpose of this article.

It is important to note that adding mining resources to bitcoin is rewarded by design while adding distributed database nodes (Full Nodes) is not profitable. It should surprise no one that as mining network scaled, the resouces for the distributed database node have stayed modest. For a reasonable attacker miners and their network are irrelevant.

### Full-node resources
Many are aware of block size wars, where Bitcoin's development team chose to limit the resources needed from each full node in order to lower the barriers for entry for full nodes. This has been explained as a way to maintain decentralization. There are other limitations in the reference full node implemenation. Limiting node's capacity makes each node vulnerable to various denial of services attacks. Some of the [capacities](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h) of Full Nodes are:
1. Networking
   1. [125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L72) simultanous peer connections
   1. [11 of the 125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L64-L68) Are dedicated for outgoing connections
   1. [1](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L68) Dedicated "Feeler" connection to test availability of new nodes
1. Address Manager
   1. 1024 "[buckets](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)" for storing information about new nodes 
   1. 256 "[buckets](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)" for storing information about nodes that had been reached
   1. 64 entries in each [bucket](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L133)
   2. Publicly accessible [services](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L288) attribute for each new node
   3. [10 entries](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L165) in the collision queue.

As we shall see, any of these limitations can be attacked using [Elon](https://github.com/tsubery/elon) 

### How many full-nodes are out there?
We can use [Elon](https://github.com/tsubery/elon) to recursively crawl bitcoin's network an enumerate all nodes or look at the aformentioned scanners: [bitnodes.io](https://bitnodes.io) or [bitcoinstatus.net](http://bitcoinstatus.net). On bitnodes full nodes have odd number in their advertised services because it's defined as the [first bit](https://github.com/bitcoin/bitcoin/blob/b34bf2b42caaee7c8714c1229e877128916d914a/src/protocol.h#L276) in services field. Other nodes such as wallets are irrelevant for attackers because it's better to focus the efforts on the most constrained part of the network. Because it's common for hosts to have both ipv6 & ipv4 addresses assigned, this will lead to counting the same nodes twice. The resources described above are per node, not per interface. Having said that I estimate about 6,500 nodes at the time of writing. That means about 750k incoming connections, 65k outgoing. Even using general purpose load generation tools such as [tcpkali](https://github.com/satori-com/tcpkali), a single attacker can generate tens of thousands of tcp connections. A small group of attackers can easily consume all incoming/outgoing connections. For example they can use
```bash
targets=$(curl -H "Accept: application/json; indent=4" https://bitnodes.io/api/v1/snapshots/latest/ |\
  # pattern for node's keys
  egrep "\[\$" |\
  # remove onion addresses
  grep -v "onion" |\
  # select the inside of quoted string
  cut -d'"' -f 2 |\
  # remove ipv6 notation markers
  tr -d '[]'
  )
  
tcpkali --connect-rate 1000 --duration=1200 --connections 50000 $targets
```
On many systems you'd need to increase ulimit using a command such as `ulimit -n1000000`. Also configure [sysctl](https://github.com/satori-com/tcpkali/blob/master/doc/tcpkali.man.md#see-also). I also fixed a bug in that repo to handle [ipv6 addresses], welcome to use my fork.
Bitcoin does not implement any meaningful rate limits. When i tried it on the full node on my personal machine i could easily peg CPU @ 100% just sending ping requests. If they would have rate limits, any government/isp or tor exit node could have abused it by injecting packets. This was done in the [past](https://www.eff.org/es/wp/packet-forgery-isps-report-comcast-affair) by ISPs

### Type of attacks
While the script above are enough for activists to create outages becaues these connections can drown out legitimate connections from wallets. There are other more efficient ways of consuming networks resources as demonstrated by [Elon](https://github.com/tsubery/elon).
1. Loopback - We can listen on port 8333, when a node connects to us, we can connect to it back, and make it talk to itself. That will take out 1/10 of the connecting node's outgoing connection pool.
1. Tunnel - We connect to the same node twice and make it talk to itself.
2. Crawl - We connect to node, ask for it's list of peers and disconnect
3. Flood - We continously send ping&getaddress requests to nodes under certain latency threshold. This could have the effect of consuming all cpu resources of nodes nearby such as in the same data center.
4. Spam - We spam address book of nodes with our data. Might be the most effective method. See segement about Address Manager

### Targets
[Elon](https://github.com/tsubery/elon) supports getting targets from various sources, internal crawler, bitnodes.io api, bitcoinstatus.net or [DNS seeds](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/chainparams.cpp#L121-L129) used by "official" bitcoin sofware, it is used the [first time or runs out of peers](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.cpp#L1608). Kindly maintained by a group of randos
In order to have indepnedent visibility into the network, we should use our own crawlerer. It will recoursively ask nodes for their peers until no new peers are discovered. Connecting to a node only to ask for a list of peers is an integral part of the how the reference implementation works. When a full node launches for the  it uses these  to find targets to [solicit](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L175-L178) addresses from. These DNS entries are centrally controlled by some [randos](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/chainparams.cpp#L121-L129).
```cpp
vSeeds.emplace_back("seed.bitcoin.sipa.be"); // Pieter Wuille
vSeeds.emplace_back("dnsseed.bluematt.me"); // Matt Corallo
vSeeds.emplace_back("dnsseed.bitcoin.dashjr.org"); // Luke Dashjr
vSeeds.emplace_back("seed.bitcoinstats.com"); // Christian Decker
vSeeds.emplace_back("seed.bitcoin.jonasschnelli.ch"); // Jonas Schnelli
vSeeds.emplace_back("seed.btc.petertodd.org"); // Peter Todd
vSeeds.emplace_back("seed.bitcoin.sprovoost.nl"); // Sjors Provoost
vSeeds.emplace_back("dnsseed.emzy.de"); // Stephan Oeste
vSeeds.emplace_back("seed.bitcoin.wiz.biz"); // Jason Maurice
````
They can obviously collude to send some wallets to a subnetwork. All coiners are equal but some coiners are more equal than others.
Between these sources attackers can ensure no node is left behind.

### Bitcoin's Address Manager
While transactions are determined using expensive consensus mechanism. Node addresses are not constrained. Anyone can send addresses to nodes. There is no consensus mechanism to solve collisions. This [code comment](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L100-L124) explains Bitcoin naive defense. Key comment is
> Make sure no (localized) attacker can fill the entire table with his nodes/addresses.

It presumes a single attacker has only one address, a silly assumption on it's on. It is completely useless defense against a group of attackers. It works by deterministically use source address to restrict access to part of the data structure. As the comment explains a hash on prefix of source address is used to select 64/1024 buckets. That means single address can fill about 6% of the addresses in the data structure.  Let's say some activist pays 10$ for 15 minutes to host 200 cloud vps instances in different providers. 200 ipv4 & 400 ipv6 addresses. Let's run the numbers, the chance of a bucket *not* being selected is (1024-64)/1024 = 0.9375. The chance of 400 addresses not catching a specific bucket is (0.9375)^400, we multiply it by 1024 to get the chance for missing all of the bucket and multiply by 100 to get 0.000006% chance of not selecting any of of the buckets. In other words 99.999999% chance of filling up all "new" the addresses with our own. 
Another way to circumvent this defense is to send up to [10 addresses](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L2772) at a time, that causes peer to send those addreses to some random peers as explained [here](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L1615-L1619). Sending the same 10 addresses message to all nodes in the network will effectively make it arrive 300 times to nodes in the network, covering all buckets. So attackers can choose to send 1000 addresses per message 60 times or 10 peers 6000 times (reconnecting each time) to wipe out "new" table.

When a bitcoin node receive information about a peer, it uses a [lookup table](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L210) keyed by [CNetAddr](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#119) without port numbers, yet it stores addresses with their port in order to be able to connect. That means that when a node accepts address with two different ports it will keep the first one. This can be obviously exploited attackers can flood the "new" list with garbage then immediately flood it with correct addresses with wrong ports. That would effectively block communication to the corrupted node entries as long as the attacked node keep receiving falsified updates that they are reachable. Attackers can also override every node's [advertised services](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L288) because bitcoin uses bitwise or to add new advertised services. That will make nodes connect to wallets and waste resources.

When outgoing connections from "new" table complete successful handshake, they are [promoted](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L200) to "tried". Note that here it does check that we refer to the same [port](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L215) because it uses CService and CAddree that do contain port information. Promoted addresses are less likely to be evicted, and have even smaller data structure of with maximum of 16,384 addresses, in practice address can appear in multiple buckets so it's even more limited. An obvious problem is the lack of distinction between ipv6 address and ipv6 range. Many hosting providers offer ipv6 range of 2^64. That means an attacker can respond to btc handshake on any of those addresses quickly overflowing the "tried" table with a single host.
