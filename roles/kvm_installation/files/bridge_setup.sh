#!/bin/bash

brctl addbr br1
ifconfig br1 up
ifconfig br1 10.1.0.254 netmask 255.255.0.0
