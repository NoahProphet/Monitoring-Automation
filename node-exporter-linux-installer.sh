#!/bin/sh -e

abort()
{
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred. Exiting..." >&2
    exit 1
}

trap 'abort' 0

set -e

# If an error occurs, the abort() function will be called.


#Set Password for node-exporter
PASSWORD_OF_SERVER="Change it"
SERVER_IP="Change it"
SERVER_USER="Change it"
USER="Change it"
PASSWD="Change it"

#check root
_check_root () {
    if [ $(id -u) -ne 0 ]; then
        echo "Please run as root" >&2;
        exit 1;
    fi
}


_check_internet () {
 if hash nc 2>/dev/null; then
     if nc -zw1 google.com 443; then
       echo "+ we have Internet"
     else
       echo "- The network access to internet is down"
       exit 1;
     fi
 else
     if ping -q -c 1 -W 1 google.com >/dev/null; then
       echo "+ we have Internet"
     else
       echo "- The network access to internet is down"
       exit 1;
     fi
 fi

}


_check_ufw_add_rule () {
echo "+checking ufw..."
sudo ufw status > ufw.tmp
if grep -q "inactive" ufw.tmp ; then
  echo "+ ufw disable"
else
  echo "+ ufw enable"
#  sudo ufw allow from $SERVER_IP to any port 9100
fi
rm ufw.tmp

}


_check_root

_check_internet

_check_ufw_add_rule


#adduser
sudo apt install sshpass -y

#rm -r ssl
mkdir -p /etc/node-exporter
mkdir -p ssl
if id node_exporter &>/dev/null; then
    echo 'user found'
else
    sudo useradd -rs /bin/false node_exporter
    echo 'user not found so make it'
fi



wget http://$USER:$PASSWD@$SERVER_IP:80/data/ssl.tar.gz -o ssl.tar.gz
#sshpass -p "$PASSWORD_OF_SERVER" scp -r ssl/prom_node_cert.pem monitoring@$SERVER_IP:/home/monitoring/prometheus/prometheus/ssl/prom_node_cert.pem
echo "copy ssl file."

FILE_EXPORTER_SERVICE=/lib/systemd/system/node-exporter.service
if [ -f "$FILE_EXPORTER_SERVICE" ]; then    
  sudo systemctl stop node-exporter.service
fi

FILE_EXPORTER=node_exporter
if [ -f "$FILE_EXPORTER" ]; then
    sudo cp node_exporter /usr/local/bin
else
    wget http://$USER:$PASSWD@$SERVER_IP:80/data/node_exporter-1.3.1.linux-amd64 -o node_exporter
fi

sudo cp node_exporter /usr/local/bin
sudo cp ssl/prom_node_cert.pem /etc/node-exporter/prom_node_cert.pem
sudo cp ssl/prom_node_key.pem /etc/node-exporter/prom_node_key.pem
sudo cp ssl/prometheus_cert.pem /etc/node-exporter/prometheus_cert.pem
sudo chown node_exporter /usr/local/bin/node_exporter
sudo chmod +x /usr/local/bin/node_exporter
#configuring node-exporter file and folder

cat << EOF > /etc/node-exporter/web.yml
tls_server_config:
  cert_file: /etc/node-exporter/prom_node_cert.pem
  key_file: /etc/node-exporter/prom_node_key.pem
  client_auth_type: RequireAndVerifyClientCert
  client_ca_file: /etc/node-exporter/prometheus_cert.pem

EOF

sudo chown -R node_exporter /etc/node-exporter
if [ -x "$(command -v systemctl)" ]; then
    cat << EOF > /lib/systemd/system/node-exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.config.file=/etc/node-exporter/web.yml

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable node-exporter
    systemctl start node-exporter

else
    echo "No known service management found" >&2;
    exit 1;
fi

rm -r ssl
sudo apt purge sshpass -y


trap : 0

echo >&2 '
************
*** DONE *** 
************
'

