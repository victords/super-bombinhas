#!/bin/bash

ruby bundle.rb
mv sb.rb deb/opt/vds-games/super-bombinhas/
cp -r data deb/opt/vds-games/super-bombinhas/
dpkg -b deb super-bombinhas-1.5.2.deb
