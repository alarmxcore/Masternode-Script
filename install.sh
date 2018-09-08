#!/bin/bash
clear

# Set these to change the version of Alarmx to install
TARBALLURL="https://github.com/alarmxcore/alarmx/releases/download/v0.12.2/alarmxcore-0.12.2-linux64.tar.gz"
TARBALLNAME="alarmxcore-0.12.2-linux64.tar.gz"
VERSION="0.12.2"

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  echo "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
clear

echo "
 +-------------- MASTERNODE INSTALLER v1.0 -------+
 |                                                |
 |You can choose between two installation options:|::
 |             default and advanced.              |::
 |                                                |::
 | The advanced installation will install and run |::
 |  the masternode under a non-root user. If you  |::
 |  don't know what that means, use the default   |::
 |              installation method.              |::
 |                                                |::
 | Otherwise, your masternode will not work, and  |::
 |the AlarmX Team CANNOT assist you in repairing  |::
 |        it. You will have to start over.        |::
 |                 AlarmX $VERSION                |::
 |Don't use the advanced option unless you are an |::
 |            experienced Linux user.             |::
 |                                                |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::
"

sleep 5

read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=alarmx

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

echo "" && echo 'Added user "alarmx"' && echo ""
sleep 1

else

USER=root

fi

USERHOME=`eval echo "~$USER"`

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key (e.g. 6KDR3vtjKLHexzLB63LLFB3Y5buw6HxLPVz6UuiyxfouMpcyvoy # THE KEY YOU GENERATED EARLIER) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget git htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install libevent-pthreads-2.0-5 && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 2579/tcp
  yes | ufw enable
fi
#rm $TARBALLNAME
# Install Alarmx daemon
wget $TARBALLURL && tar -xzvf $TARBALLNAME && cd alarmxcore-$VERSION/bin && cp ./alarmxd /usr/local/bin && cp ./alarmx-cli /usr/local/bin && cd /root && rm -rf alarmxcore-$VERSION
#cp ./alarmx-tx /usr/local/bin
#cp ./alarmx-qt /usr/local/bin
#rm -rf alarmxcore-$VERSION

# Create .alarmxcore directory
mkdir $USERHOME/.alarmxcore

# Install bootstrap file
#if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
#  echo "Installing bootstrap file..."
#  wget $BOOTSTRAPURL && unzip $BOOTSTRAPARCHIVE -d $USERHOME/.alarmxcore/ && rm $BOOTSTRAPARCHIVE
#fi

# Create alarmx.conf
touch $USERHOME/.alarmxcore/alarmx.conf
cat > $USERHOME/.alarmxcore/alarmx.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:2579
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
EOL
chmod 0600 $USERHOME/.alarmxcore/alarmx.conf
chown -R $USER:$USER $USERHOME/.alarmxcore

sleep 1

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
sudo systemctl start alarmxd
sudo systemctl start alarmxd.service

#clear

#clear
#echo "Your masternode is syncing. Please wait for this process to finish."

until su -c "alarmx-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 5
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

#echo "Your masternode is syncing. Please wait for this process to finish."
#echo "CTRL+C to exit the masternode sync once you see the MN ENABLED in your local wallet." && echo ""

#until su -c "alarmx-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
#  for (( i=0; i<${#CHARS}; i++ )); do
#    sleep 2
#    echo -en "${CHARS:$i:1}" "\r"
#  done
#done

sleep 1
su -c "/usr/local/bin/alarmx-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/alarmx-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." && echo ""
