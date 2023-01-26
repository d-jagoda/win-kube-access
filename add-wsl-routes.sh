#!/usr/bin/env bash

# This script connects WSL's root net namespace with net namespace that has the Container Network Interface (CNI) and adds routing rules to make Pod and Cluster IPs accessible from WSL and ultimately Windows

# Default pod and cluster IP ranges
POD_IP_RANGE=10.1.0.0/16
CLUSTER_IP_RANGE=10.96.0.0/12

for i in `seq 1 10`;
do
	CONTAINERD_PID=$(ps -o pid,args | grep "[u]sr/bin/containerd$" | awk -F ' ' '{print $1}')
	if [ -z "$CONTAINERD_PID" ]
	then
		echo "Docker is not running"
		exit 1
	fi

	for pid in `lsns --type net -o pid,command -n | awk -F ' ' '{print $1}'`; do
		if [ "$pid" != "1" ] 
		then
			CNI_IP=$(nsenter -t $pid -n ip -4 addr show cni0 2> /dev/null | grep inet | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}')
			if [ "$CNI_IP" ==  "10.1.0.1" ]
			then
				TARGET_PID=$pid
				TARGET_PROCESS_CMD=$(tr -d '\0' < /proc/$pid/cmdline)
				echo "Found networking namespace with cni0. PID=$TARGET_PID, Command=$TARGET_PROCESS_CMD"
				break
			fi
		fi
	done

	if [ -z "$TARGET_PID" ]
	then
		echo "Could not find network namespace with cni0. Kubernetes may still be starting up. Trying again in 10 seconds"
		sleep 10s
	else
		break
	fi
done

if [ -z "$TARGET_PID" ]
then
	echo "Could not find network namespace with cni0. Kubernetes may not be running"
	exit 1
fi

# Remove veth-kubeaccess (if it exists) to clean up the previous configuration
echo "Cleaning up previous setup"
ip link del veth-kubeaccess > /dev/null 2>&1

set -e

## CONFIGURE WSL ROOT NET NAMESPACE ##
# Create veth pair to connect WSL root net namespace with CNI net namespace
ip link add veth-kubeaccess type veth peer name veth-wslaccess

# Configure veth-kubeaccess and bring it up
ip addr add 192.168.2.1/24 dev veth-kubeaccess
ip link set veth-kubeaccess up

# Add routing rules to access Pod and cluster ip ranges
ip route add $POD_IP_RANGE dev veth-kubeaccess
ip route add $CLUSTER_IP_RANGE dev veth-kubeaccess

# Enable proxy ARP handle address resolution queries for CNI net namespace
echo 1 > /proc/sys/net/ipv4/conf/all/proxy_arp

# Move the veth peer to CNI net namespace
ip link set veth-wslaccess netns $TARGET_PID

## CONFIGURE THE CNI NET NAMESPACE ##
nsenter -t $TARGET_PID -n ip addr add 192.168.2.2/24 dev veth-wslaccess
nsenter -t $TARGET_PID -n ip link set veth-wslaccess up

# Network math to derive WSL network address from eth0's IP address and net mask
WSL_IP=$(ip -4 addr show eth0 | grep inet | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}')
WSL_NET_MASK_INT=$(ip -4 addr show eth0 | grep inet | awk -F ' ' '{print $2}' | awk -F '/' '{print $2}')
WSL_IP_SEGMENTS=(${WSL_IP//./ })
WSL_IP_INT=$(((${WSL_IP_SEGMENTS[0]} << 24 ) | (${WSL_IP_SEGMENTS[1]} << 16 ) | (${WSL_IP_SEGMENTS[2]} << 8 ) | ${WSL_IP_SEGMENTS[3]}))

WSL_NET_MASK_BITS=$((((2 ** $WSL_NET_MASK_INT) - 1) << (32 - $WSL_NET_MASK_INT)))
WSL_NETWORK_INT=$((WSL_IP_INT & WSL_NET_MASK_BITS))
WSL_NETWORK="$(((WSL_NETWORK_INT & 0xFF000000) >> 24)).$(((WSL_NETWORK_INT & 0x00FF0000) >> 16)).$(((WSL_NETWORK_INT & 0x0000FF00) >> 8)).$((WSL_NETWORK_INT & 0x000000FF))"

# Add a routing rule to access the WSL network (includig windows) from CNI net namespace
nsenter -t $TARGET_PID -n ip route add $WSL_NETWORK/$WSL_NET_MASK_INT dev veth-wslaccess

# Enable proxy ARP handle address resolution queries for container net namespaces
nsenter -t $TARGET_PID -a /bin/bash -c 'echo 1 > /proc/sys/net/ipv4/conf/all/proxy_arp'

echo "Done!"