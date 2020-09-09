#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -d ~/asterisk ]; then
  echo "A directory already exists at $HOME/asterisk"
  echo "Remove it before running this script."
  exit 1
fi

if [ -d /etc/asterisk ]; then
  echo "A directory already exists at /etc/asterisk"
  echo "Remove it or back it up because this script will destroy it."
  exit 1
fi

if [ ! -f ./etc-asterisk/asterisk.conf ]; then
  echo "You didn't clone this repository with submodules"
  echo "run: git submodule update --init"
  exit 1
fi

# tools
sudo apt-get -y update
sudo apt-get -y install dos2unix lame gawk sed ssmtp

# install prerequisites
cd $SCRIPTDIR/asterisk/contrib/scripts
sudo ./install_prereq install
sudo ./install_prereq install-unpackaged
cd $SCRIPTDIR/asterisk
./contrib/scripts/get_mp3_source.sh
cd $SCRIPTDIR/asterisk
./configure
cd menuselect
make
cd ..
./menuselect/menuselect --enable format_mp3 --enable format_wav --enable EXTRA-SOUNDS-EN-GSM menuselect.makeopts
make
sudo make install
sudo make config
sudo make install-logrotate

# remove /etc/asterisk and replace with our own setup
sudo rm -rf /etc/asterisk
sudo mkdir /etc/asterisk
sudo cp -rf $SCRIPTDIR/etc-asterisk/* /etc/asterisk/

# set up service
sudo useradd -U -s /usr/sbin/nologin -M asterisk
sudo tar xfvz -C /var/lib/asterisk $SCRIPTDIR/sounds.tgz
sudo chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /var/run/asterisk
sudo sed -i 's/#AST_/AST_/g' /etc/default/asterisk

# change letsencrypt folder permissions so asterisk user can get to them
if [ -d /etc/letsencrypt ]; then
  sudo chgrp -R asterisk /etc/letsencrypt
  sudo find /etc/letsencrypt -type d -exec chmod g+rx {} \;
  sudo find /etc/letsencrypt -type f -exec chmod g+r {} \;
fi
