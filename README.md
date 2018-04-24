# arpspoof_all
A wrapper around arpspoof that facilitates spoofing multiple targets on the local network.


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

