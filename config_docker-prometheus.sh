#!/bin/bash

#help : bash config_docker.sh --name_prj sanay --logstash_port 2021 --promtail_port 1514 --prometheus_port 2022
# bash config_docker-prometheus.sh --name_prj sanay --prometheus_port 5031

PASSWORD="\$"
ARGUMENT_LIST=(
    "name_prj"
    "prometheus_port"

)

# read arguments
opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "" \
    -- "$@"
)

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name_prj)
            NAME=$2
            shift 2
            ;;

        --prometheus_port)
            PROM_PORT=$2
            shift 2
            ;;

        *)
            break
            ;;
    esac 
done



echo "prj_name: $NAME";
mkdir -p $NAME/{prometheus_data,config}
echo "$PASSWORD" | sudo -S mkdir -p /var/log/monitoring/$NAME/prometheus

mkdir -p ssl
if [ -z "$(ls -A ssl)" ]; then
   openssl req -x509 -newkey rsa:1024 -keyout ssl/prom_node_key.pem -out ssl/prom_node_cert.pem -days 29220 -nodes -subj /commonName=prom_node/ -addext "subjectAltName=DNS:prom_node"
   openssl req -x509 -newkey rsa:2048 -keyout ssl/prometheus_key.pem -out ssl/prometheus_cert.pem -days 29220 -nodes -subj /commonName=prometheus/ -addext "subjectAltName=DNS:prometheus"
   echo "+make SSL files"
else
   echo "-SSL files exist"
fi

rm -rf $NAME/config/prometheus/ssl
cp -r default_conf/prometheus/config/ $NAME/;
cp -r ssl $NAME/config/prometheus
cp default_conf/prometheus/docker-compose-prometheus.yml $NAME/docker-compose-prometheus.yml
echo "+ copy default config";

mkdir -p nginx
tar -zcvf ssl.tar.gz ssl
if [ -z "$(ls -A nginx)" ]; then
    cp -r default_conf/nginx/* nginx/
    cp -r ssl.tar.gz nginx/data
    wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz -o nginx/data/node_exporter-1.3.1.linux-amd64.tar.gz
else 
    echo "nginx files exist"
fi


sed -i -e "s/NAME/${NAME}/g" $NAME/docker-compose-prometheus.yml;
sed -i -e "s/PROMETHEUS-PORT/${PROM_PORT}/g" $NAME/docker-compose-prometheus.yml;

echo "$PASSWORD" | sudo -S docker-compose -f $NAME/docker-compose-prometheus.yml up -d
echo "$PASSWORD" | sudo -S docker-compose -f $NAME/docker-compose-prometheus.yml restart

echo "$PASSWORD" | sudo -S docker-compose -f nginx/docker-compose-nginx.yml up -d
echo "$PASSWORD" | sudo -S docker-compose -f nginx/docker-compose-nginx.yml restart

echo "+ docker-compose file changed."
#netstat -na | grep -w 909 | awk '{print$4}' |grep -w 909|sed -e "s/127.0.0.1://g" | sed -e "s/://g" | sort -u
#Run Docker compose:
#cd  $SITE_NAME && docker-compose -f docker-compose -prometheus.yml up -d
#sudo docker build -f Dockerfile -t bulud-waf:latest .

