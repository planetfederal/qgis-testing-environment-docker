#!/bin/bash
# Provisioning file for Vagrant

# Build the docker fetching the repo and branch

# Note on naming for tags:
# Image repo    branch                  tags
# qgis          master                  master
# boundless     release_2_14-boundless  release_2_14-boundless, release, latest


REPO=${1:-https://github.com/qgis/QGIS.git}
BRANCH=${2:-master}
TAG=${3:-master}
DOCKER_HUB_USERNAME=$4
DOCKER_HUB_PASSWORD=$5
DOCKER_HUB_ACCOUNT=$6
if [ -z "$6" ]; then
    DOCKER_HUB_ACCOUNT=${DOCKER_HUB_USERNAME}
fi
IMAGE_NAME=${DOCKER_HUB_ACCOUNT}/qgis-testing-environment

echo "Image name: $IMAGE_NAME"

cd
if [ ! -d "qgis-testing-environment-docker" ]; then
    git clone https://github.com/boundlessgeo/qgis-testing-environment-docker.git
fi
cd qgis-testing-environment-docker
# Delete all containers
IM_TO_RM=$(docker ps -a -q)
if [ -n "$IM_TO_RM" ]; then
    docker rm $IM_TO_RM
fi
# Delete all images
IM_TO_RM=$(docker images -q ${IMAGE_NAME})
if [ -n "$IM_TO_RM" ]; then
    docker rmi $IM_TO_RM
fi
docker build -t ${IMAGE_NAME}:${TAG} \
    --build-arg QGIS_REPOSITORY=$REPO \
    --build-arg QGIS_BRANCH=$BRANCH .

HASH=`git rev-parse HEAD|cut -c -8`
docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:${HASH}

# Push the image to Docker Hub
if [ -n "${DOCKER_HUB_PASSWORD}" ]; then
    docker login -u ${DOCKER_HUB_USERNAME} -p ${DOCKER_HUB_PASSWORD}
    # Do not tag with hash or we will accumulate a lot of old images on the hub
    #docker push ${IMAGE_NAME}:${HASH}
    docker push ${IMAGE_NAME}:${TAG}
fi
