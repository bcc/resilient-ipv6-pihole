# Redundant PiHoles with working IPv6 resolution

I was getting fed up with Mikrotik's DNS and DHCP and the apparent afterthought that their IPv6 integration is, and at the same time I patched the vm server that my pihole lives on, which reminded me that I've been meaning to set up a second one for resilience. Overkill? Maybe. Satisfying though.

## Instructions 

Set up pair of pihole servers. Give them static IP addresses. I'm using one on a VM running ubuntu, and one on a raspberry pi running raspbian.

### Static allocations 

Edit the `pihole/hosts.local` file and set up any static IPs that you wish to assign. Duplicate hostnames for IPv4 and IPv6 entries. There are more examples in the file, but this will be used for both A and AAAA records, as well as PTR records for the reverse entries.

    192.168.6.10            desktop
    2a02:c0ff:ee::10        desktop 

Define MAC addresses and hostnames in `dnsmasq.d/04-pihole-static-dhcp.conf` using the following format. These will be used for IPv4 and IPv6 lookups on the local network.

    dhcp-host=B8:27:EB:AA:AA:AA,desktop
    dhcp-host=B8:27:EB:BB:BB:BB,pizero

Next you'll need to enter your own specific values for DNS server addresses and domain names into `dnsmasq.d/02.local.conf`:

    addn-hosts=/etc/pihole/hosts.local
    local=/example.com/
    domain=example.com
    expand-hosts
    dhcp-option=6,192.168.6.3,192.168.6.4
    dhcp-option=option6:dns-server,[2a02:c0ff:ee::3],[2a02:c0ff:ee::4]
    ra-param=*,0,0

Finally, if your piholes are not called 'pihole1' and 'pihole2' then edit the line at the top of `sync-local.sh`. If you don't have any working DNS at the moment, you can put IP addresses there instead. 

### SSH Key setup 
We'll use an ssh key to make distributing the files easy. You can run this anywhere you like, but it needs access to both your pihole servers. A normal user home directory on pihole1 is a good place if you don't have anywhere else. 

Generate SSH key:

    ssh-keygen -f id_dnsdhcp

And then place the content of `id_dnsdhcp.pub` in `/root/.ssh/authorized_keys` on each of your pihole servers. Make sure the permissions on that file and directory are correct: 

    root@pihole2:~# ls -lad .ssh/ .ssh/authorized_keys
    drwx------ 2 root root 4096 Jan  1 00:09 .ssh/
    -rw-r--r-- 1 root root  393 Jan  1 00:08 .ssh/authorized_keys

If they're wrong, fix them: 

    chmod 700 /root/.ssh
    chmod 644 /root/.ssh/authorized_keys 

### DHCP configuration 

In the pihole interface on pihole1, log into the admin interface and go to Settings, then DHCP. Enable the DHCP server, and set an IP range for dynamic IPv4 addresses. I used 192.168.6.80 to 192.168.6.95 here. It's best if this doesn't overlap any addresses you wish to assign statically. I also set my local domain name and router IP (192.168.6.1 in my case) and I set the lease time to 1 hour. You can increase it later when you're happy that everything works. DO NOT tick the 'Enable IPv6 support' box at this point. Don't enter any static lease information at this point. Click on save. 

Then repeat the same settings on pihole2, but give it a different DHCP range. I used 192.168.6.96 to 192.168.6.111 for this one. This ensures that dynamic addresses handed out by each pihole won't overlap. 

The next setting to configure on each of the pihole servers is a file which will be different on each one. 
On pihole1 create `/etc/dnsmasq.d/5.v6-range.conf`, with the following content:

    dhcp-range=::300,::3ff,constructor:ens3,ra-names,slaac,1h

You'll need to change 'ens3' to whatever the name of the network interface you're using - you can find this out using 'ip addr sh'

On pihole2, the file will be different, and again you'll want to make sure the interface name is correct. In my case, it's eth0 on the raspberry pi:

    dhcp-range=::400,::4ff,constructor:eth0,ra-names,slaac,1h

The difference in these files defines the IPv6 dynamic range in the same way that we did for IPv4 addresses above - in this case pihole1 will issue addresses in the range 2a02:c0ff:ee::300 to 2a02:c0ff:ee::3ff. The reason we start at 300 and 400 is because the IPv6 address space is greater, and it means we can use 0 to 255 to match the static IPv4 allocations for consistency. Not needed, but it looks nicer. 

### Deploy! 
Run ./sync-local.sh - the first time you run it, if you've not SSHed into your piholes already, you'll be asked to confirm ssh host keys. Every time you run it, it will check to see if the files have been changes, print out a diff of the changes, then restart the pihole service to reload the configuration. 

Once this has happened, you'll notice that the 'Static DHCP leases configuration' table under the 'DHCP' tab in pihole is now populated with your MAC and hostname pairs. If you update them in the web interface, they will be overwritten next time you run 'sync-local.sh' though.

IPv6 leases under 'Currently active DHCP leases' do look a bit strange as dnsmasq doesn't log the mac address, but they do work correctly. 

Remember to disable DHCP on your router so it doesn't conflict with your piholes, and it's worth checking that your router isn't handing out IPv6 DNS servers via RA. On the Mikrotik RouterOS interface, it's under IPv6, ND, Advertise DNS. Enjoy your working resilient DNS and DHCP!
