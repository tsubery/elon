# Bitcoin security vulnerabilities
## TLDR;
Bitcoin wastes immense amounts of [energy](https://digiconomist.net/bitcoin-energy-consumption). It's community is complicit with crime and uses divisive marketing tactics. This poses great risk of backlash from the rest of society. For example, using [Elon](https://github.com/tsubery/elon) to create long running outages of Bitcoin's network. This could render private wallets, where most of the "value" is stored, unusable for long periods at a time. When holders will realize access to their assets can be controlled by angry mobs they will be less inclined to use it as store of value. [Professionals](https://www.youtube.com/watch?v=pcToFASnyrc) are aware and have been warning about these issues. Hackers & Bitcoin salesepeople would like to keep the following information out of sight because it might kill their golden goose.

## Overview

Bitcoin's open nature is touted as a feature, In reality it makes it a sitting duck for various forms of attack. Current information about participants is availabe on https://bitnodes.io and http://bitcoinstatus.net. Because all the addresses are public, it's easy to see most of the nodes are hosted in data centers such as Amazon, Google, Microsoft, etc. It would be easy to point out the hypocracy of these companies providing services to support bitcoin while publicizing their [ESG goals](https://aws.amazon.com/blogs/enterprise-strategy/it-and-esg-part-two-how-it-can-and-must-further-the-companys-esg-efforts/) and buying [carbon credits](https://www.geekwire.com/2020/amazon-pledges-10m-forest-preservation-carbon-offsets-appalachians/). They have colluded in the past to kick [Parler](https://edition.cnn.com/2021/01/09/tech/parler-suspended-apple-app-store/index.html). Bitcoin can face the same treatment.
Like any distributed computer system, Bitcoin has certain capacities that can be consumed by attackers in order to render services [unavailable](https://en.wikipedia.org/wiki/Denial-of-service_attack) for normal usage. These limitations are kept intentionally low in order to make the software more "decentralized" for marketing purposes, making the network vulnerable to long durations of service outages outside exchanges that are likely to have priviledged coordination mechanisms.

## Estimating networks capacity
The myth that Bitcoin's network has massive capacity relies on technical slight of hand. The network is comprised of three different nodes which contribute and consume different resources to the network.

1. Full Nodes - These are distributed data stores backed by [Level DB](https://github.com/bitcoin/bitcoin/tree/55a156fca08713b020aafef91f40df8ce4bc3cae/src/leveldb). They provide services of data query & propagation.
2. Wallet Nodes - These are typically short lived nodes, they do not store the full database of around 360GB at the time of writing. These nodes do not publish "NETWORK_NODE" bit to to inform other participants of their limited capacity. 
3. Miner Nodes - These nodes encompass the majority of resources of the network. Since mining is done in private these are not a target for crowd sourced attack and are irrelevant for the purpose of this article.

It is important to note that adding mining resources to bitcoin is rewarded by design while adding distributed database nodes (Full Nodes) is not profitable. It should surprise no one that as mining network scaled, the resouces for the distributed database node have stayed modest. For a reasonable attacker miners and their network are irrelevant.

### Full-node resources
Some of the [limitations](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h) of a Full Node are:
1. Networking
   1. [125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L72) Total simultanous peer connections
   3. [10 of the 125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L64-L68) Are dedicated for outgoing peer connections
   4. [1](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L68) Dedicated "Feeler" connection to test reachability of addresses. These occur every [2 minutes](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L68)
   5. [114](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L72) Incoming connections
1. Address Manager
   1. 1024 "[buckets](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)" of for storing information about new nodes 
   1. 256 "[buckets](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)" for storing information about nodes that had been reached
   1. 64 entries in each [bucket](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L133)
   3. [10 entries](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L165) in the collision queue that get preferrence when trying new connections

As we shall see, any of these limitations can be attacked using [Elon](https://github.com/tsubery/elon) 

### How many full-nodes are out there?
We can use [Elon](https://github.com/tsubery/elon) to recursively crawl bitcoin's network an enumerate all nodes or look at the aformentioned scanners: [bitnodes.io](https://bitnodes.io) or [bitcoinstatus.net](http://bitcoinstatus.net). On bitnodes full nodes have odd number in their advertised services because it's defined as the [first bit](https://github.com/bitcoin/bitcoin/blob/b34bf2b42caaee7c8714c1229e877128916d914a/src/protocol.h#L276). Other nodes such as wallets are irrelevant for attackers because they mostly consume resources from the network. Because it's common for hosts to have both ipv6 & ipv4 addresses assigned, many nodes will be counted twice even though the limitations are per host and not per interface. Having said that I estimate that there are about 6,500 reachable nodes at the time of writing. That means network capacity of 750k incoming connections, 65k outgoing. Even using general purpose load generation tools such as [tcpkali](https://github.com/satori-com/tcpkali), a single attacker can generate tens of thousands of tcp connections. A small group of attackers can easily consume all incoming/outgoing connections. For example they can use
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
On many systems you'd need to increase ulimit using a command such as `ulimit -n1000000`. Also configure [sysctl](https://github.com/satori-com/tcpkali/blob/master/doc/tcpkali.man.md#see-also). I also fixed a bug in that repo to handle [ipv6 addresses], welcome to use the fork from my [Pull Request](https://github.com/satori-com/tcpkali/pull/73).
Bitcoin does not implement any meaningful rate limits. When i tried it on the full node on my personal machine i could easily peg CPU @ 100% just sending ping requests. If they would have rate limits, any government/isp or tor exit node could have abused it by injecting packets. This was done in the [past](https://www.eff.org/es/wp/packet-forgery-isps-report-comcast-affair) by ISPs trying to limit other P2P networks.

### Type of attacks supported by Elon
The script above is enough for activists to create outages becaues these connections can drown out legitimate connections from wallets. Yet, there are other more efficient ways of consuming networks resources. All are demonstrated by [Elon](https://github.com/tsubery/elon).
1. Loopback - It listens on port 8333 of all availabe addresses. When a node connects to us, it tries to connect to it back, and make it talk to itself. If connection back fails it just sends "version" message and keep the connection open. This would cause our address to be [promoted](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L200). Bitcoin cannot penalize peers for timeouts and network distruptions because they can and often occur due to 3rd parties. This attack can consume multiple connections out of the limited prioritize pool of only 10 outgoing connections each node has.
1. Tunnel - It is a very similar way of consuming resources, this time focusing on incoming connection pool. Instead of listening and waiting for connections, it actively connects to the same node twice and make it talk to itself. Incoming connections are more likely to be dropped but can be reopened them as many times as needed. 
2. Crawl - It connects to each node, ask for it's list of peers N times and disconnect. These queries are only one cheap packet for us yet cause complicated database lookup for other nodes.
3. Flood - During crawling it identifies nodes that are nearby and have low latency. They can be targeted specifically with endless loop of ping and getaddr. This could cause their CPUs to max out, potentially dropping their connections to other peers. It would dislocate them from their preferred status with other peers as long lived connection, potentially freeing up spots other attack nodes.
4. Spam -  spam address book of nodes with bad data. Might be the most effective method. See segement about Address Manager

### Targets
[Elon](https://github.com/tsubery/elon) supports getting targets from various sources:
* Internal crawler - Scans nodes recursively and collect latency information from each node
* [Bitnodes.io api](https://bitnodes.io/api/) - See their documentation for more details
* http://bitcoinstatus.net/active_nodes.json - A list of recently reachable full nodes
* [DNS seeds](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/chainparams.cpp#L121-L129) used by "official" bitcoin sofware, it is used the [first time or runs out of peers](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.cpp#L1608). 
 
Connecting to a node only to ask for a list of peers is an integral part of the how the "official" implementation works so the internal crawler is expected to be the most availabe option to collect targets. When a full node launches for the first time it uses this pattern to [solicit](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L175-L178) addresses from peers seeded by DNS entries.
These DNS entries are centrally controlled a group of [randos](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/chainparams.cpp#L121-L129).
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
Bitcoin does not implement any [partition](https://datacadamia.com/data/distributed/network_partition) detection so they keep the option to collude by sending some wallets to an isolated subnetwork. The subnetwork could delay or reject publishing particular transactions, particular peers or present out of date information to selected wallets. Wallets can not be aware of the manipulation because all peers they know started with those DNS entries. All coiners are equal but some coiners are more equal than others.

### Bitcoin's Address Manager
While transactions are determined using expensive consensus mechanism. Node addresses are not constrained. Anyone can connect and immediately send addresses to nodes. There is no consensus mechanism to solve collisions. This [code comment](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L100-L124) explains Bitcoin naive defense. Key comment is
> Make sure no (localized) attacker can fill the entire table with his nodes/addresses.

It presumes a single attacker has only one address, a naive assumption at best or abdication of responsibility at worst. It is completely useless defense against a group of attackers. It works by deterministically using source address to restrict access to subsection of the data structure. As the comment explains a hash on prefix of source address is used to select 64/1024 buckets. That means single address can fill about 6% of the addresses in the data structure.  Let's say some activist pays 10$ for 15 minutes to host 200 cloud vps instances in different providers. 200 ipv4 & 400 ipv6 addresses. Let's run the numbers, the chance of a bucket *not* being selected is (1024-64)/1024 = 0.9375. The chance of 400 addresses not catching a specific bucket is (0.9375)^400, we multiply it by 1024 to get the chance for missing all of the bucket and multiply by 100 to get 0.000006% chance of not selecting any of of the buckets. In other words 99.999999% chance of filling up all "new" the addresses with our own. 
Another way to circumvent this defense is to send up to [10 addresses](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L2772) at a time, that causes peer to send those addreses to some random peers as explained [here](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L1615-L1619). Sending the same 10 addresses message to all nodes in the network will effectively make it arrive 300 times to nodes in the network, covering all buckets. So attackers can choose to send 1000 addresses per message 60 times or 10 peers 6000 times (reconnecting each time) to wipe out "new" table.

When a bitcoin node receive information about a peer, it uses a [lookup table](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L210) keyed by [CNetAddr](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#119) without port numbers, yet it stores addresses with their port in order to be able to connect. That means that when a node accepts address with two different ports it will keep the first one. This can be obviously exploited attackers can flood the "new" list with garbage then immediately flood it with correct addresses with wrong ports. That would effectively block communication to the corrupted node entries as long as the attacked node keep receiving falsified updates that they are reachable. Attackers can also override every node's [advertised services](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L288) because bitcoin uses bitwise or to add new advertised services. That will make nodes connect to wallets and waste resources.

When outgoing connections from "new" table receive version message, they are [promoted](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L200) to "tried". Note that here it does check that whether refer to the same [port](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L215) because it uses CService and CAddree that do contain port information. Promoted addresses are less likely to be evicted, and have even smaller data structure of with maximum of 16,384 addresses, in practice address can appear in multiple buckets so it's even more limited. An obvious problem is the lack of distinction between ipv6 address and ipv6 range. Many hosting providers offer ipv6 range of 2^64. That means an attacker can respond to btc handshake on any of those addresses quickly overflowing the "tried" table with a single host.

### Mitigating attacks
In order to mitigate attacks Bitcoin developers must increase connection limitations, address manager size, introduce some rate limitations on various interactions and implement a mechanism to avoid centralization of "tried" connections similar to what is implemented by "bucketing" by sources address. Also the RelayAddress functionality seems like a bad idea because it negates the address flood protections. As mentioned, this will inevitably exclude some lower specs nodes out of the network which is something they were reluctant to do in the past.
