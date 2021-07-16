#!/bin/bash
IMAGEID=$(docker images | awk -v repo="$REPOSITORY" -v tag="local" 'index($1, repo) && index($2, tag) {print $3}')

echo "$filename"
echo "$docker_username"
echo "$REPOSITORY_NAME"
echo "$VERSION"
echo "${IMAGEID}"
#
docker tag "${IMAGEID}" ${docker_username}/${repository_name}:${version}
docker tag "${IMAGEID}" ${docker_username}/${repository_name}:latest

docker push ${docker_username}/${repository_name}:${version}
docker push ${docker_username}/${repository_name}:latest
#cleanup
docker rmi -f ${IMAGEID}