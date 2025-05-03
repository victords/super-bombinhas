#!/bin/bash

ruby bundle.rb
mkdir -p deb/opt/vds-games/super-bombinhas
mv sb.rb deb/opt/vds-games/super-bombinhas/
cp -r data deb/opt/vds-games/super-bombinhas/
dpkg -b deb super-bombinhas-1.5.4.deb
