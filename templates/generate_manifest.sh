#!/bin/bash
#generate_manifest.sh

director_uuid=$(bosh status --uuid)

if [[  "$1" != "bosh-lite" && "$1" != "aws" ]]
  then
    echo "Usage: generate_manifest.sh bosh-lite|aws"
    exit 1
fi

if [ "$1" == "bosh-lite" ] 
  then
    spiff merge templates/cephfs-manifest-boshlite.yml <(echo "director_uuid: ${director_uuid}") > cephfs-manifest.yml
fi

if [ "$1" == "aws" ] 
  then
    spiff merge templates/cephfs-manifest-aws.yml <(echo "director_uuid: ${director_uuid}") > cephfs-manifest.yml
fi

bosh deployment cephfs-manifest.yml
