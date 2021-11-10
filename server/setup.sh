#!/bin/bash

export USER_PSWD
export ROOT_PSWD
NET=nx
PORT=8080
DB_NAME=nextcloud

USER=admin
MARIA_NAME=maria
PODMAN_COMMON="--detach --security-opt label=disable --restart=unless-stopped " #--network $NET  --restart on-failure

function renew_clean(){
  local IMAGE=$1
  local NAME=$2
  echo ">>> Cleanup $NAME"
  podman pull ${IMAGE}
  podman stop ${NAME}
  podman rm ${NAME}
}

function podman_mariaDB(){
  local VOLUME=$1
  local NAME=$MARIA_NAME
  local IMAGE=mariadb #:10
  local DBS=$DB_NAME
  local DB_PORT=3306
  #renew_clean ${IMAGE} ${NAME}
  podman run $PODMAN_COMMON \
    --env MYSQL_DATABASE=${DBS} \
    --env MYSQL_USER=${DBS} \
    --env MYSQL_PASSWORD=${USER_PSWD} \
    --env MYSQL_ROOT_PASSWORD=${ROOT_PSWD} \
    --volume ${VOLUME}:/var/lib/mysql:Z \
    --publish ${DB_PORT}:${DB_PORT} \
    --name ${NAME} \
    ${IMAGE}
  #
}

function podman_nextcloud(){
  local VOLUME_APP=$1
  local VOLUME_DATA=$2

  local NAME=nextcloud
  local IMAGE=$NAME # :20
  local DB_HOST=localhost
  local NX_ADMIN=$USER
  local NX_PSWD=$DB_PASSWORD
  #renew_clean ${IMAGE} ${NAME}
  podman run $PODMAN_COMMON \
    --env MYSQL_HOST=$DB_HOST \
    --env MYSQL_DATABASE=$DB_NAME \
    --env MYSQL_USER=$DB_NAME \
    --env MYSQL_PASSWORD=$USER_PSWD \
    --env NEXTCLOUD_ADMIN_USER=$NX_ADMIN \
    --env NEXTCLOUD_ADMIN_PASSWORD=$USER_PSWD \
    --volume $VOLUME_APP:/var/www/html:Z \
    --volume $VOLUME_DATA:/var/www/html/data:Z \
    --name $NAME \
    --publish ${PORT}:80 \
    $IMAGE
}

function podman_homeassistant(){
  local NAME=hass
  #local IMAGE=homeassistant/home-assistant:stable
  local IMAGE=docker.io/library/homeassistant/raspberrypi4-homeassistant:stable
  local VOLUME=$1
  renew_clean ${IMAGE} ${NAME}
  podman run $PODMAN_COMMON \
    --volume /etc/localtime:/etc/localtime:ro \
    --volume $VOLUME:/config:Z \
    --name $NAME \
    --network=host \
    $IMAGE
}
  

function start(){
  ROOT_PSWD=${USER_PSWD}
  local TARGET_PATH=$1
  if [ -z "$TARGET_PATH" ]; then
    TARGET_PATH="$(pwd)"
  fi
  echo ">>> Using Path: $TARGET_PATH"
  mkdir $TARGET_PATH/volume_maria $TARGET_PATH/volume_nx_app $TARGET_PATH/volume_nx_data $TARGET_PATH/volume_hass
  
  #podman network create $NET
  podman_mariaDB $TARGET_PATH/volume_maria
  podman_nextcloud $TARGET_PATH/volume_nx_app $TARGET_PATH/volume_nx_data
  podman_homeassistant $TARGET_PATH/volume_hass
  
}

function nx_rescan(){
  local USER=$1
  local NX_USER=www-data
  if [ -z "$USER" ]; then
    USER="--all"
  fi
  local NAME=nextcloud
  podman exec -ti --user $NX_USER $NAME /var/www/html/occ files:scan $USER
}

function create_image_mariadb(){
  git clone https://github.com/jscotka/mariadb-docker.git docker-mariadb
  (
    cd docker-mariadb
    podman build -t mariadb -f 10.3/Dockerfile
  )
}

function create_image_nextcloud(){
  git clone https://github.com/jscotka/nextcloud-docker.git docker-nextcloud
  (
    cd docker-nextcloud
    podman build -t nextcloud -f 22/apache/Dockerfile
  )
}


USER_PSWD="$1"
TARGET_PATH="$2"

if [ -n "$USER_PSWD" ]; then
   start "$TARGET_PATH"
fi
