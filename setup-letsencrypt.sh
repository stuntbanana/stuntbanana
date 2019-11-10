#!/bin/bash

if [[ "$1" == "" ]]; then
  echo "Specify a contact email address for your certificate"
  exit 1
fi

echo Setting up Let\'s Encrypt...

sudo apt-get -y update
sudo apt-get -y install software-properties-common
sudo add-apt-repository -y ppa:certbot/certbot
sudo apt-get -y update
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d $(hostname) -m $1 --agree-tos -n

echo Finished setting up Let\'s Encrypt
