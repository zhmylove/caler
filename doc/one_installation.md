apt-get install -y g++ bison default-jdk flex javahelper libmysql++-dev libsqlite3-dev libssl-dev libws-commons-util-java libxml2-dev libxmlrpc-c++8-dev libxmlrpc3-client-java libxmlrpc3-common-java libxslt1-dev ruby scons
apt-get install -y ruby-dev sqlite3
groupadd --gid 1002 oneadmin
mkdir /home/one
useradd --uid 1002 -g oneadmin -s /bin/bash -d /var/lib/one oneadmin
oneadmin passwd changeit
cd ~/one
scons
./install.sh -u oneadmin -g oneadmin
cd /usr/share/one
./install_gems

apt-get install -y nodejs npm
npm config set http-proxy http://proxy:3128 
npm config set https-proxy http://proxy:3128 
npm set strict-ssl false 
npm —proxy 192.168.2.1:3128 —without-ssl —insecure install -g bower 
/usr/local/bin/bower -> /usr/local/lib/node_modules/bower/bin/bower 
bower@1.8.0 /usr/local/lib/node_modules/bower
npm install -g grunt
/usr/local/bin/grunt -> /usr/local/lib/node_modules/grunt/bin/grunt
grunt@1.0.1 /usr/local/lib/node_modules/grunt
npm install -g grunt-cli
/usr/local/bin/grunt -> /usr/local/lib/node_modules/grunt-cli/bin/grunt
grunt-cli@1.2.0 /usr/local/lib/node_modules/grunt-cli
cd /usr/lib/one/sunstone/public
apt-get install nodejs-legacy
npm install
vi .bowerrc
>"registry": "http://bower.herokuapp.com",
>"proxy": "http://proxy:3128",
>"https-proxy": "http://proxy:3128",
>"strict-ssl": false 

~/one/src/sunstone/public# cat ~/.gitconfig 
[http] 
proxy = http://proxy:3128 
[url "https://github.com/SPICE/spice-html5"] 
insteadOf = git://anongit.freedesktop.org/spice/spice-html5

cd
mkdir .one
vi .one/one_auth
>oneadmin:changeit
chmod 600 !!:^
one start
sunstone-server start
sunstone-server stop
one stop
./install.sh -r

cd /usr/lib/one/sunstone/public/
npm install
bower install
grunt sass
grunt requirejs
cd ~/one
scons
./install.sh -u oneadmin -g oneadmin
/usr/share/one/install_gems
export ONE_AUTH=/home/user/.one/one_auth
one start
sunstone-server start
oneflow-server start

#KVM INSTALL
apt-update
apt-get install qemu-kvm libvirt-bin virtinst
adduser oneadmin kvm
adduser oneadmin libvirt
adduser oneadmin libvirt-qemu
su - oneadmin
chown oneadmin /var/lib/one/datastores/.isofiles/
apt install genisoimage 

#virtual network settings
brctl addbr br0
#/etc/network/interfaces
auto eth0 
iface eth0 inet manual 

auto eth1 
iface eth1 inet manual 

auto br0 
iface br0 inet dhcp 
bridge_ports eth0 eth1 
bridge_stp off 
bridge_waitport 0 
bridge_fd 0

#set passwordless ssh
cd
ssh-keygen -t rsa
cd .ssh
cat id_rsa.pub >> authorized_keys
ssh-keyscan onekorg2 >> ./known_hosts

#template config
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]" ]
CPU = "1"
DISK = [
  IMAGE_ID = "11" ]
DISK = [
  IMAGE_ID = "13" ]
FEATURES = [
  ACPI = "yes" ]
GRAPHICS = [
  LISTEN = "0.0.0.0",
  TYPE = "VNC" ]
HYPERVISOR = "kvm"
MEMORY = "1024"
NIC = [
  NETWORK = "localnetwork",
  NETWORK_UNAME = "oneadmin" ]
OS = [
  ARCH = "x86_64",
  BOOT = "disk0" ]
VCPU = "1"

#fix connect to OneFlow
vi /var/lib/one/.one/one_endpoint
>http://localhost:2633/RPC2
oneflow-server stop
oneflow-server start
