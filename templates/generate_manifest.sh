#!/bin/bash
#generate_manifest.sh

director_uuid=$(bosh status --uuid)

usage () {
    echo "Usage: generate_manifest.sh bosh-lite|aws [cephfs*|cephdriver|both]"
    echo " * default"
    exit 1
}

if [[  "$1" != "bosh-lite" && "$1" != "aws" ]]
  then
    usage
fi

ARG2=cephfs-bosh-release

DIRECTOR_YML=$(cat <<END_HEREDOC
name: ${ARG2}
director_uuid: ${director_uuid}
releases:
    - name: ${ARG2}
END_HEREDOC
)

if [ "$2" == "cephfs" -o "$2" == "" ]
    then
    MANIFEST_NAME=cephfs-manifest
    CEPHFS_PROPERTIES_YML=$(cat <<END_HEREDOC

properties:
  cephbroker: {}
  cephfs: {}
END_HEREDOC
)
    CEPHFS_JOB_YML=$(cat <<END_HEREDOC
jobs:
- name: cephfs
  templates:
  - release: ${ARG2}
    name: cephfs
  - release: ${ARG2}
    name: cephbroker
END_HEREDOC
)
elif [ "$2" == "cephdriver" ]
    then
    MANIFEST_NAME=cephdriver-manifest
    CEPHDRIVER_PROPERTIES_YML=$(cat <<END_HEREDOC

properties:
 cephdriver:
  driver_paths: "/var/vcap/data/voldrivers"
END_HEREDOC
)
    CEPHDRIVER_JOB_YML=$(cat <<END_HEREDOC

jobs:
- name: cephdriver
  templates:
  - {release: ${ARG2}, name: cephdriver}
END_HEREDOC
)
elif [ "$2" == "both" ]
    then
    MANIFEST_NAME=ceph-manifest
    PROPERTIES_YML=$(cat <<END_HEREDOC

properties:
  cephbroker:
   listenAddr: "0.0.0.0:8009"
   dataPath: "/var/vcap/data/cephbroker/data"
   catalogPath: "/var/vcap/data/cephbroker/catalog"
  cephdriver:
   driver_paths: "/var/vcap/data/voldrivers"
END_HEREDOC
)
    CEPHFS_AND_CEPHDRIVER_AND_CEPHBROKER_JOB_YML=$(cat <<END_HEREDOC

jobs:
- name: cephfs
  templates:
  - {release: ${ARG2}, name: cephfs}
  - {release: ${ARG2}, name: cephbroker}
- name: cephdriver
  templates:
  - {release: ${ARG2}, name: cephdriver}
END_HEREDOC
)
else
    usage
fi

SUBSTITUTION=$(cat <<END_HEREDOC
${DIRECTOR_YML}
${CEPHFS_JOB_YML}
${CEPHDRIVER_JOB_YML}
${CEPHFS_AND_CEPHDRIVER_AND_CEPHBROKER_JOB_YML}
${CEPHFS_PROPERTIES_YML}
${CEPHBROKER_PROPERTIES_YML}
${CEPHDRIVER_PROPERTIES_YML}
${PROPERTIES_YML}
END_HEREDOC
)

if [ "$1" == "bosh-lite" ]
  then
    spiff merge templates/cephfs-manifest-boshlite.yml <(echo "${SUBSTITUTION}") > $MANIFEST_NAME.yml
fi

if [ "$1" == "aws" ]
  then
    spiff merge templates/cephfs-manifest-aws.yml <(echo "${SUBSTITUTION}") > $MANIFEST_NAME.yml
fi

bosh deployment $MANIFEST_NAME.yml
