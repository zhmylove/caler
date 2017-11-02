#!/bin/bash

onehost create $HOSTNAME --im kvm --vm kvm 

oneimage create --datastore default --name test --type DATABLOCK --persistent --driver qcow2 --size 8192

oneimage chtype test OS

onevnet create /var/lib/one/vnet1.conf
onetemplate create /var/lib/one/template.tmpl 
onetemplate instantiate test-templ
