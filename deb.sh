#!/bin/bash

# Aleva Deb Generation Script

cp -R deb deb_temp
sudo chmod 6775 -R deb_temp
sudo chmod a-s -R deb_temp/DEBIAN
sudo chmod a+x deb_temp/DEBIAN/postinst
sudo chown root: -R deb_temp
dpkg -b deb_temp .
sudo rm -rf deb_temp
