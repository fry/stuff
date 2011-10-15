This repository just contains code/tools that don't actually deserve their
own repository.

eve_asset_audit.rb
------------------
A short script that uses the EVE API to build a list of assets for every
character and then calculates how much each character's assets are worth
in Jita averages prices. The prices are loaded from eve-central.
Requires the EAAL EVE API library fork gem from https://github.com/fry/eaal

transparent_vpn.rb
------------------
An OpenVPN client wrapper that takes control over how routes or addresses are
created for a new connection. Instead of having to rely on the routes pushed
down by the server, the script sets up proper ifconfig, routing and iptables
rules so the local endpoint of the VPN TUN device is the chosen IP without
affecting the default route for normal network traffic.
This allows new outgoing sockets to be created and bound to the chosen IP even
if you have multiple VPN clients whose servers push down conflicting routes, for
example the same local IP.
At the moment it still requires a special routing table to be created for each
connection.

