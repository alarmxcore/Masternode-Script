#!/bin/bash

clear
echo "This script will refresh your masternode."
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep alarmxd) | grep alarmxd | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

if [ -e /etc/systemd/system/alarmxd.service ]; then
  systemctl stop alarmxd
else
  su -c "alarmx-cli stop" $ALRMXUSER
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf $USERHOME/.alarmxcore/blocks
rm -rf $USERHOME/.alarmxcore/database
rm -rf $USERHOME/.alarmxcore/chainstate
rm -rf $USERHOME/.alarmxcore/peers.dat

cp $USERHOME/.alarmxcore/alarmx.conf $USERHOME/.alarmxcore/alarmx.conf.backup
sed -i '/^addnode/d' $USERHOME/.alarmxcore/alarmx.conf

if [ -e /etc/systemd/system/alarmxd.service ]; then
  sudo systemctl start alarmxd
else
  su -c "alarmxd -daemon" $USER
fi

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

until su -c "alarmx-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\r"
  done
done

sleep 1
su -c "/usr/local/bin/alarmx-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/alarmx-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
