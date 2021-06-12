# Evaluate Live Open Nodes
[Elon](https://github.com/tsubery/elon) is a toolkit that allows various interactions with bitcoin nodes. It is unencumbered by the artificial restrictions of the official software.
The official node software scales because it prioritizes services to other nodes over users self interest. For example, it is limited to [10](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L64-L68) outgoing connections while allowing [125](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L72) incoming. The balance is heavily skewed towards providing services rather than consuming by a factor of 11. In order to get up to date information and send transactions reliably with official node software you’d need to operate a node cluster and preferably collude with others to prioritize mutual communications.
Using Elon you too can get priority access without the community service. You can quickly send messages to all nodes instead of waiting forever for your transaction to propagate. It also supports various attacks to demonstrate how the official software is kept vulnerable to aggravate priority disparities during crashes.

## [Usage](#usage)
1. Install ruby using your preferred package manager
1. `gem install bunder`
2. `bundle`
1. `./elon.rb -h` for a complete list of features

For maximum performance you need to increase system limitations using `ulimit -n 100000` and [systctl](https://github.com/satori-com/tcpkali/blob/master/doc/tcpkali.man.md#see-also)

## [Features](#features)
It can compile a list of reachable nodes by crawling, dns seeds, [bitnodes.io](https://bitnodes.io) or [bitcoinstatus.net](http://bitcoinstatus.net). During crawling it can flood all nodes or focus on nodes with low latency. It can crawl accurately using ruby, or fast using tcpkali load generator tool. While crawling it can publish a message to each reachable node. It can supports generating version & address messages. In order to submit transactions you'll need the relevant INV message.

Loopback feature allows it to listen on port 8333, upon incoming connection it tries to connect back to the same peer and make the node talk to itself. If it can’t connect back it just sends “version” message like a normal node and waits. This has the effect of taking a place in Bitcoin [‘tried’]((https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L130)) table. Since it only has space for 16k addresses and each address can appear up to 8 times. If enough attackers use this it would cause serious disruptions.
It can also serve as a relatively cheap place holder if you don’t want to run full node all the time but want to have priority when you do run your wallet. If you run this feature when your full node is not running, many nodes will mark your address as reachable. When you open your wallet you will not need to wait days for peers to connect to you.

Tunnel is a similar idea, focusing on outgoing connections, It connects to the same node twice and makes it talk to itself. You can use this to test your nodes capacity and resource usage.

### [Network size](#network-size)
Many crawlers count short lived wallets or the same host twice using their ipv6 & ipv4 address. From my research there are about 6,500 full nodes operating at the moment. That means the whole public unprivileged class network has capacity of about 65000 outgoing connections and 750,000. Using this script on several computers could cause significant disruptions for the common node.
```bash
#!/bin/bash
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
If you wish to use tcpkali with ipv6 addresses you can use my [fork](https://github.com/satori-com/tcpkali/pull/73). Even using basic flooding techniques on my full node I could easily peg the CPU at 100% because official node software does not implement defenses such as automatically banning flooding nodes. This keeps your node vulnerable to the most basic of attacks. Sophisticated players must have firewals and privileged access from other nodes making sure their service quality is protected.

### [Bitcoin's Address Manager](#address-manager)
While transactions are determined using expensive consensus mechanism. Node addresses are not constrained. Anyone can connect and immediately send addresses to nodes. There is no consensus mechanism to solve collisions. This [code comment](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.h#L100-L124) explains Bitcoin naive defense. Key comment is
> Make sure no (localized) attacker can fill the entire table with his nodes/addresses.

It presumes a single attacker has only one address, a naive assumption at best or abdication of responsibility at worst. It is a completely useless defense against a group of attackers. It works by deterministically using source address to restrict access to subsection of the data structure. As the comment explains a hash on prefix of source address is used to select 64/1024 buckets. That means single address can fill about 6% of the addresses in the data structure. Addresses are very cheap, especially ipv6 or onion. Anyone that spends few dollars to gain access to several hundreds of ips for few minutes can wipe out the whole data structure. Decent software would put a rate limit in place to avoid it.
Another way to circumvent this defense is to send only [10 addresses](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L2772) at a time, that causes peer to send those addresses to some random peers as explained [here](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L1615-L1619). Sending the same 10 addresses message to all nodes in the network will effectively make it arrive on average 3 times to each node in the network, covering multiple buckets. 

When a bitcoin node receive information about a peer, it uses a [lookup table](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L210) keyed by [CNetAddr](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#119) without port numbers, yet it stores addresses with their port in order to be able to connect. That means that when a node accepts an address with two different ports it will keep the first one. This can be obviously exploited. Attackers can flood the "new" list with garbage then immediately flood it with correct addresses with wrong ports. That would effectively block communication to the corrupted node entries as long as the attacked node keeps receiving falsified updates that they are reachable at the wrong port. Attackers can also override every node's [advertised services](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/addrman.cpp#L288) because bitcoin uses bitwise or to add new advertised services. That will make nodes connect to wallets and waste resources.

### [How to mitigate](#mitigate)
My bitcoin [fork](https://github.com/tsubery/bitcoin) has higher connection limits and a larger address manager so it is more resistant to attacks, has better visibility into ongoing transactions.
