#!/usr/bin/env ruby

require 'open3'

def x(*args)
	puts "#{__FILE__} executing: #{args.join(' ')}"
	Open3.popen3(*args)
end

def xe(*args)
	_, stdout, stderr = x(*args)
	error = stderr.read
	puts "Error: #{error}" if not error.empty?
end

if ENV.include? 'script_type' then
	overwrite_ip = ENV['CFG_LOCAL_IP'] != ENV['ifconfig_local'] and ENV['CFG_LOCAL_IP'] != "default"
	local_ip = overwrite_ip ? ENV['CFG_LOCAL_IP'] : ENV['ifconfig_local']
		
	table = ENV['CFG_ROUTE_TABLE']

	type = ENV['script_type']
	device = ENV['dev']

	ifconfig = "/sbin/ifconfig"
	ip = "/sbin/ip"
	iptables = "/sbin/iptables"

	iptables_args = ["POSTROUTING", "-t", "nat", "-s", ENV['CFG_LOCAL_IP'], "-o", device, "-j", "SNAT", "--to-source", ENV['ifconfig_local']]

	if type == "up" then
		xe(ifconfig, device, local_ip, "pointopoint", ENV['ifconfig_remote'],
			"mtu", ENV['tun_mtu'])
	elsif type == "route-up" then
		xe(ip, "rule", "add", "from", local_ip, "table", table)
		xe(ip, "route", "add", "default", "via", ENV['ifconfig_remote'],
		      "dev", device, "table", table)
		
		# register iptables rule if we're picking our own ip
		xe(iptables, "-A", *iptables_args) if overwrite_ip

		# spawn socat process
		socat_port = ENV['CFG_SOCAT_PORT']
		socat_dest = ENV['CFG_SOCAT_DEST']
		if socat_port and socat_dest
			x("socat", "-d", "-v", "-v", "TCP4-LISTEN:#{socat_port},fork,reuseaddr",
        "TCP4:#{socat_dest},bind=#{local_ip}")
		end
	elsif type == "down" then
		xe(ifconfig, device, "0.0.0.0")
		xe(ip, "rule", "del", "from", local_ip)
		xe(ip, "route", "del", "default", "table", table)
		
		# clear iptables rule
		xe(iptables, "-D", *iptables_args) if overwrite_ip
	end
else
	require 'optparse'
	require 'ostruct'
	require 'pp'

	options = OpenStruct.new
	options.socat_port = 26001
	options.ip = "default"
	
	opts = OptionParser.new do |opts|
		opts.banner = "Usage: #{__FILE__} [options]"
		
		opts.on("-c", "--config CONFIG",
						"The OpenVPN CONFIG file to use") do |config|
			options.config = config
		end
		
		opts.on("-d", "--dev [DEVICE]", "The TUN device for OpenVPN to use",
					  "default is to create a temporary device") do |dev|
			options.device = dev
		end
		
		opts.on("-b", "--bind [IP]", "The local IP to use",
					 "default is to use the one assigned by the server") do |ip|
			options.ip = ip
		end
		
		opts.on("-t", "--table TABLE",
					 "The routing table to use for setting up the default route",
					 "has to be created beforehand") do |table|
			options.table = table
		end
		
		opts.on("-s", "--socat [DEST]", "Setup a socat TCP redirect through the " +
																		"VPN to DEST") do |dest|
			options.socat_dest = dest
		end
		
		opts.on("-p", "--port [PORT]", Integer, "The port for socat to listen on") do |port|
			options.socat_port = port
		end
		
		opts.on_tail("-h", "--help", "Print this help") do
			puts opts
			exit
		end
	end

	if ARGV.empty?
		puts opts
		exit
	end
	
	remains = opts.parse!(ARGV)

	env_args = [
		["CFG_LOCAL_IP", options.ip],
		["CFG_ROUTE_TABLE", options.table],
		["CFG_SOCAT_PORT", options.socat_port],
		["CFG_SOCAT_DEST", options.socat_dest]
	]

  args = ["openvpn",
	  "--config", options.config,
	  "--script-security", "2",
	  "--route-nopull",
	  "--ifconfig-noexec",
	  "--up", __FILE__,
	  "--down", __FILE__,
	  "--route-up", __FILE__]

  args += env_args.find_all do |env|
		not env[1].nil?
	end.map do |env|
	  ["--setenv", env[0].to_s, env[1].to_s]
	end.flatten

  args += ["--dev", options.device] if options.device
	
  system(*args)
end

