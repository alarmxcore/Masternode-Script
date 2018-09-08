#!/bin/bash
clear

TARBALLURL="https://github.com/alarmxcore/alarmx/releases/download/v0.12.2/alarmxcore-0.12.2-linux64.tar.gz"
TARBALLNAME="alarmxcore-0.12.2-linux64.tar.gz"
VERSION="0.12.2"

CHARS="/-\|"

clear
echo "
 +----------------------------------------------------script.v1.4+::
 | Alarmx Masternode Update Script Version: $VERSION           |::
 |                                                               |::
 | This script is complemintary to the original install script.  |::
 | If you manually installed, please update your VPS manually.   |::
 |                                                               |::
 +---------------------------------------------------------------+::
"
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

#USER=`ps u $(pgrep alarmxd) | grep alarmxd | cut -d " " -f 1`
USER=root
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/alarmxd.service ]; then
  systemctl stop alarmxd
else
  su -c "alarmx-cli stop" $USER
fi

echo "Upgrading alarmx..."
#mkdir ./alarmx-temp #&& cd ./alarmx-temp
rm *
wget $TARBALLURL
tar xvf $TARBALLNAME #&& mv bin alarmxcore-$VERSION
rm $TARBALLNAME

cp -f ./alarmxd /usr/local/bin
cp -f ./alarmx-cli /usr/local/bin
# cp -f ./alarmx-tx /usr/local/bin
#rm test*

#if [ -e /usr/bin/alarmxd ];then rm -rf /usr/bin/alarmxd; fi
#if [ -e /usr/bin/alarmx-cli ];then rm -rf /usr/bin/alarmx-cli; fi
#if [ -e /usr/bin/alarmx-tx ];then rm -rf /usr/bin/alarmx-tx; fi

#sed -i '/^addnode/d' ./.alarmxcore/alarmx.conf
chmod 0600 ./.alarmxcore/alarmx.conf
#chown -R $USER:$USER ./.alarmxcore

echo "Restarting alarmx daemon..."
if [ -e /etc/systemd/system/alarmxd.service ]; then
  systemctl start alarmxd
else
  cat > /etc/systemd/system/alarmxd.service << EOL
[Unit]
Description=alarmxd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/alarmxd -conf=${USERHOME}/.alarmxcore/alarmx.conf -datadir=${USERHOME}/.alarmxcore
ExecStop=/usr/local/bin/alarmx-cli -conf=${USERHOME}/.alarmxcore/alarmx.conf -datadir=${USERHOME}/.alarmxcore stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
  sudo systemctl enable alarmxd
  sudo systemctl start alarmxd.service

fi

sleep 10
cd /usr/local/bin
su -c "alarmx-cli stop" $USER
echo "########reindexing"
sleep 6
echo "########starting"
su -c "alarmxd -reindex" $USER
sleep 6

until su -c "alarmx-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 7
    #echo -en "${CHARS:$i:1}" "\r"
    clear
    echo "Service Started. Your masternode is syncing.
    When Current = Synced then select your MN in the local wallet and start it.
    Script should auto finish here."
    echo "
    Current Block: "
    su -c "curl https://explorer.alarmx.io/api/getblockcount" $USER
    echo "
    Synced Blocks: "
    su -c "alarmx-cli getblockcount" $USER
  done
done

clear
su -c "/usr/local/bin/alarmx-cli getinfo" $USER
su -c "/usr/local/bin/alarmx-cli masternode status" $USER
echo "" && echo "Masternode setup completed." && echo ""
