# Installation of application for one

## Prepare one node

```sh
apt-get update
apt-get install haproxy
brctl addbr br1
brctl addbr br2
ifconfig br1 up
ifconfig br2 up
ifconfig br1 10.1.0.254 netmask 255.255.0.0
ifconfig br2 10.2.0.254 netmask 255.255.0.0
```

## Prepare ha1 node of app1

```sh
dhclient eth0
apt-get install haproxy
apt-get install isc-dhcp-server
vi  /etc/default/isc-dhcp-server
>INTERFACES="eth1"
vi /etc/dhcp/dhcpd.conf
> option domain-name-servers 8.8.8.8, 8.8.4.4;
> authoritative;
> subnet 10.1.0.0 netmask 255.255.255.0 {
> range 10.1.0.2 10.1.0.253;
> option routers 10.1.0.1;
> on commit {
>       set vmIP = binary-to-ascii(10, 8, ".", leased-address);
>       execute("/usr/local/bin/haproxy-add", vmIP);
>    }
> }
> on release {
>       set vmIP = binary-to-ascii(10, 8, ".", leased-address);
>       execute("/usr/local/bin/haproxy-del", vmIP);
>    }
> }
```

## Prepare app node template

```sh
apt-get update
apt-get install nodejs
vi /lib/systemd/system/getty@.service
> s#ExecStart=-/sbin/agetty --noclear %I $TERM#ExecStart=-/sbin/agetty --noclear -a oneadmin %I $TERM
vi ~/.profile
> /usr/bin/nodejs "$HOME/server.js"
```
