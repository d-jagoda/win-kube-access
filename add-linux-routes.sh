#!/usr/bin/env bash

# These are pretty static by default
POD_IP_RANGE=10.1.0.0/16
CLUSTER_IP_RANGE=10.96.0.0/12

# Find the PID of kube-proxy which we will use later on to resolve the net namespace of kube-proxy
#KUBE_PROXY_NS_PID=$(lsns --type net -o PID,COMMAND | grep "unshare -muinpf --propagation=unchanged --kill-child=SIGTERM /usr/local/bin/wsl-bootstrap jump" | awk -F ' ' '{print $1}')
KUBE_PROXY_PID=$(ps -o pid,comm | grep kube-proxy | awk -F ' ' '{print $1}')
echo "KUBE_PROXY_PID=$KUBE_PROXY_PID"

# Start by cleaning up the existing network setup by deleting one of the veth devices, which should delete everything else
echo "Cleaning up previous setup"
ip link del veth-kgateway > /dev/null 2>&1

## IN THE ROOT NAMESPACE ##
# Enable proxy ARP so that windows will route to hops over 1
echo 1 > /proc/sys/net/ipv4/conf/all/proxy_arp

# Create veth pair to connect the root namespace with kube-proxy's net namespace (veth-wsl will be moved to kube-proxy)
ip link add veth-kgateway type veth peer name veth-wsl

# We can chose any ip range that doesn't clash with another network setup in the two namespaces we are trying to connect
ip addr add 192.168.2.1/24 dev veth-kgateway
ip link set veth-kgateway up
# Route the ip ranges that we want accessible from windows via this device
ip route add $POD_IP_RANGE dev veth-kgateway
ip route add $CLUSTER_IP_RANGE dev veth-kgateway

# Ugly bits (maybe there is an easier way) - We need to calculate the network address from eth0's ip, which is in the same network as the host's WSL interface
WSL_IP=$(ip -4 addr show eth0 | grep inet | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}')
WSL_NET_MASK_INT=$(ip -4 addr show eth0 | grep inet | awk -F ' ' '{print $2}' | awk -F '/' '{print $2}')
WSL_IP_SEGMENTS=(${WSL_IP//./ })
WSL_IP_INT=$(((${WSL_IP_SEGMENTS[0]} << 24 ) | (${WSL_IP_SEGMENTS[1]} << 16 ) | (${WSL_IP_SEGMENTS[2]} << 8 ) | ${WSL_IP_SEGMENTS[3]}))

WSL_NET_MASK_BITS=$((((2 ** $WSL_NET_MASK_INT) - 1) << (32 - $WSL_NET_MASK_INT)))
WSL_NETWORK_INT=$((WSL_IP_INT & WSL_NET_MASK_BITS))
WSL_NETWORK="$(((WSL_NETWORK_INT & 0xFF000000) >> 24)).$(((WSL_NETWORK_INT & 0x00FF0000) >> 16)).$(((WSL_NETWORK_INT & 0x0000FF00) >> 8)).$((WSL_NETWORK_INT & 0x000000FF))"

# Move the veth peer to kube-proxy's net namespace
ip link set veth-wsl netns $KUBE_PROXY_PID

## IN THE KUBE-PROXY'S NAMESPACE ##
nsenter -t $KUBE_PROXY_PID -n ip addr add 192.168.2.2/24 dev veth-wsl
nsenter -t $KUBE_PROXY_PID -n ip link set veth-wsl up

# We need to route traffic from windows back through the same path they came through - veth-kproxy
nsenter -t $KUBE_PROXY_PID -n ip route add $WSL_NETWORK/$WSL_NET_MASK_INT dev veth-wsl

echo "Linux Side Done!"