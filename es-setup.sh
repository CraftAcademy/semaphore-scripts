#! /usr/bin/env bash
set -e 
####
# Description: Replaces default ElasticSearch version with version specified as parameter. Waits for ES service
# to become available and uses caching to speed up the install process.
#
# Runs on: All platforms
#
# Usage:
# Add the line below to your setup command in Project Settings
#
# wget https://raw.githubusercontent.com/craftacademy/semaphore-scripts/master/es-setup.sh  && bash es-setup.sh <es-version>
#
# For example, the following command will install ES version 7.10.1 and cache its installation on Semaphore:
#
# wget https://raw.githubusercontent.com/craftacademy/semaphore-scripts/master/es-setup.sh  && bash es-setup.sh 7.10.2
#
# Note: Script does not properly detect if the ES version 2.x is started so it will hang on this step.
####



ES_HOST="0.0.0.0"
ES_PORT="9200"
ES_VERSION=${1:-'5.0.0'}
DEB='elasticsearch-'"$ES_VERSION"'.deb'
if [ $(echo $ES_VERSION | cut -d "." -f 1) = "7"  ]
then
  DEB='elasticsearch-'"$ES_VERSION"'-amd64.deb'
fi
URL="https://artifacts.elastic.co/downloads/elasticsearch/$DEB"


function stall_for_elasticsearch() {
  echo ">> Waiting for ElasticSearch to become available"

  while true; do
    printf "."

    nc -4 -w 5 $ES_HOST $ES_PORT 2>/dev/null && break
    sleep 1
  done
  
  printf "\n"
}

function setup_java() {
  echo ">> Installing Java"
  source /opt/change-java-version.sh
  change-java-version 8
}

function remove_installed_version() {
  echo ">> Sopping current ElasticSearch service"
  #sudo service elasticsearch stop
  sem-service stop elasticsearch
  #sudo apt-get purge -f -y elasticsearch
  #sudo rm -rf /var/lib/elasticsearch
}

function install_new_version() {
  if ! [ -e $SEMAPHORE_CACHE_DIR/$DEB ]; then (cd $SEMAPHORE_CACHE_DIR; wget $URL); fi

  echo ">> Installing ElasticSearch $ES_VERSION"
  echo 'Y' | sudo dpkg -i $SEMAPHORE_CACHE_DIR/$DEB

  #sudo service elasticsearch start
  sudo /etc/init.d/elasticsearch restart
  #sem-service start elasticsearch

  echo ">> Installation completed"
}

function run_health_check() {
  echo ">> Running health check..."
  curl http://"$ES_HOST":"$ES_PORT"/_cluster/health?pretty=true
}


setup_java

remove_installed_version

install_new_version

stall_for_elasticsearch

run_health_check
