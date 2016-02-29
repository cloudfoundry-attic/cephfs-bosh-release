#!/bin/bash
#generate_manifest.sh

director_uuid=$(bosh status --uuid)

if [[  "$1" != "bosh-lite" && "$1" != "aws" ]]
  then
    echo "Usage: generate_manifest.sh bosh-lite|aws"
    exit 1
fi

ARG2=${2:-cephfs-bosh-release}
SUBSTITUTION=$(printf "name: %s\ndirector_uuid: %s" "${ARG2}" "${director_uuid}")

echo $SUBSTITUTION

if [ "$1" == "bosh-lite" ] 
  then
    spiff merge templates/cephfs-manifest-boshlite.yml <(echo "${SUBSTITUTION}") > cephfs-manifest.yml
fi

if [ "$1" == "aws" ] 
  then
    spiff merge templates/cephfs-manifest-aws.yml <(echo "${SUBSTITUTION}") > cephfs-manifest.yml
fi

bosh deployment cephfs-manifest.yml
