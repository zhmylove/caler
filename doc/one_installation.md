# Installation guide for OpenNebula

## for Debian GNU/Linux 8.7 (jessie)

```sh
# apt install libssl-dev libxml-dev g++ libxmlrpc-c3-dev scons libsqlite3-dev libmysqlclient-dev libxml2-dev libssl-dev liblog4cpp5-dev ruby gem
# git clone https://github.com/OpenNebula/one.git one
# cd one
# scons
# ./install.sh
# /usr/share/one/install_gems
# /usr/share/one/install_gems sunstone
# mkdir ~/.one
# echo 'user:changeme' > ~/.one/one_auth
# chmod 600 ~/.one/one_auth
# one start
# gem install json
# gem install sinatra
# gem install thin
# sunstone-server start
# apt install nodejs npm
# ln -s /usr/bin/nodejs /usr/bin/node
# npm install -g bower
# npm install -g grunt
# npm install -g grunt-cli
# cd /usr/lib/one/sunstone/public
# npm install
# bower install --allow-root

# cd ~/one/
# gem install sass
# 

# apt install sudo
# vipw # :: oneadmin

# 
# one stop
# ./install.sh -r 
# cd ~/one
# npm install node-sass
# cd /home/user/one/src/sunstone/public/
# bower install
# scons sqlite=yes mysql=no sunstone=yes
# sudo ./install.sh -u oneadmin
# sudo /usr/share/one/install_gems sunstone cloud
# echo "oneadmin:mypassword" > ~/.one/one_auth
# one start
# ONE_AUTH=/home/user/.one/one_auth sunstone-server start
# oneflow-server start
```

