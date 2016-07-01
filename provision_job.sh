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
DOCKER_HUB_USERNAME=${4:-boundlessgeo}
DOCKER_HUB_PASSWORD=$5

IMAGE_NAME=${DOCKER_HUB_USERNAME}/qgis-testing-environment

echo "Image name: $IMAGE_NAME"

cd
if [ ! -d "qgis-testing-environment-docker" ]; then
    clone https://github.com/boundlessgeo/qgis-testing-environment-docker.git
fi
cd qgis-testing-environment-docker
# Delete all containers
docker rm $(docker ps -a -q)
# Delete all images
docker rmi $(docker images -q ${IMAGE_NAME})
docker build -t ${IMAGE_NAME}:${TAG} \
    --build-arg QGIS_REPOSITORY=$REPO \
    --build-arg QGIS_BRANCH=$BRANCH .

HASH=`git rev-parse HEAD|cut -c -8`
docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:${HASH}

# Push the image to Docker Hub
if [ "${DOCKER_HUB_PASSWORD}" -ne "" ]; then
    docker login -u ${DOCKER_HUB_USERNAME} -p ${DOCKER_HUB_PASSWORD}
    docker push ${IMAGE_NAME}:${HASH}
    docker push ${IMAGE_NAME}:${TAG}
fi
