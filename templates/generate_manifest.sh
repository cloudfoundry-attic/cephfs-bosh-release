#!/bin/bash
#generate_manifest.sh

director_uuid=$(bosh status --uuid)

if [[  "$1" != "bosh-lite" && "$1" != "aws" ]]
  then
    echo "Usage: generate_manifest.sh bosh-lite|aws"
    exit 1
fi

ARG2=${2:-cephfs-bosh-release}

SUBSTITUTION=$(cat <<END_HEREDOC
name: ${ARG2}
director_uuid: ${director_uuid}
releases:
  - name: ${ARG2}
jobs:
  - name: cephfs
    templates:
      - {release: ${ARG2}, name: cephfs}
END_HEREDOC
)

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
