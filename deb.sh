#!/bin/bash

# Aleva Deb Generation Script

ruby bundle.rb
mv sb.rb deb/opt/aleva-games/super-bombinhas/
cp -r data deb/opt/aleva-games/super-bombinhas/
dpkg -b deb super-bombinhas-0.1.2.deb
