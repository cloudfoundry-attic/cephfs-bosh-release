#!/bin/bash
#generate_manifest.sh

director_uuid=$(bosh status --uuid)

usage () {
    echo "Usage: generate_manifest.sh bosh-lite|aws cephfs*|cephdriver|both <job_ip> <cephfs_ip> <drivers_path> <keyring>"
    echo " * default"
    exit 1
}

if [[  "$1" != "bosh-lite" && "$1" != "aws" ]]
  then
    usage
fi

release_name=cephfs-bosh-release
deployment_name=$2
job_ip=$3

if [ "$2" == "cephfs" -o "$2" == "" ]
    then
    MANIFEST_FILENAME=cephfs-$1-manifest
CEPHFS_JOB_YML=$(cat <<END_HEREDOC
jobs:
- name: cephfs
  networks:
  - name: ceph-net
    static_ips:
    - $job_ip
  templates:
  - {release: ${release_name}, name: cephfs}
END_HEREDOC
)
elif [ "$2" == "cephdriver" ]
    then
    cephfs_ip=$6
    drivers_path=$4
    cephfs_keyring=`cat $5`
    MANIFEST_FILENAME=cephdriver-$1-manifest
CEPHDRIVER_JOB_YML=$(cat <<END_HEREDOC
jobs:
- name: cephdriver
  properties:
      cephdriver:
        drivers_path: $drivers_path
        cephfs_ip: $cephfs_ip
        cephfs_keyring: |
          $cephfs_keyring
  networks:
  - name: ceph-net
    static_ips:
    - $job_ip
  templates:
  - {release: ${release_name}, name: cephdriver}
END_HEREDOC
)
elif [ "$2" == "both" ]
    then
    MANIFEST_FILENAME=ceph-$1-manifest
CEPHFS_AND_CEPHDRIVER_JOB_YML=$(cat <<END_HEREDOC
jobs:
- name: cephfs
  templates:
  - {release: ${release_name}, name: cephfs}
- name: cephdriver
  templates:
  - {release: ${release_name}, name: cephdriver}
END_HEREDOC
)
else
    usage
fi

DIRECTOR_YML=$(cat <<END_HEREDOC
name: ${deployment_name}
director_uuid: ${director_uuid}
releases:
    - name: ${release_name}
END_HEREDOC
)

SUBSTITUTION=$(cat <<END_HEREDOC
${DIRECTOR_YML}
${CEPHFS_JOB_YML}
${CEPHDRIVER_JOB_YML}
${CEPHFS_AND_CEPHDRIVER_JOB_YML}
END_HEREDOC
)

if [ "$1" == "bosh-lite" ]
  then
    spiff merge templates/cephfs-manifest-boshlite.yml <(echo "${SUBSTITUTION}") > $MANIFEST_FILENAME.yml
fi

if [ "$1" == "aws" ]
  then
    spiff merge templates/cephfs-manifest-aws.yml <(echo "${SUBSTITUTION}") > $MANIFEST_FILENAME.yml
fi

bosh deployment $MANIFEST_FILENAME.yml
