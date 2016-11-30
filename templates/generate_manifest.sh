#!/bin/bash
#generate_manifest.sh

usage () {
    echo "Usage: generate_manifest.sh bosh-lite|aws cf-manifest ceph-client-keyring-stub director-stub broker-creds"
    echo " * default"
    exit 1
}

templates=$(dirname $0)

if [[  "$1" != "bosh-lite" && "$1" != "aws" || -z $3 ]]
  then
    usage
fi

if [ "$1" == "bosh-lite" ]
  then
    MANIFEST_NAME=cephfs-boshlite-manifest

    spiff merge ${templates}/cephfs-manifest-boshlite.yml \
    $3 \
    $4 \
    > $PWD/$MANIFEST_NAME.yml
fi

if [ "$1" == "aws" ]
  then
    MANIFEST_NAME=cephfs-aws-manifest

    spiff merge ${templates}/cephfs-manifest-aws.yml \
    $2 \
    $3 \
    $4 \
    $5 \
    ${templates}/stubs/toplevel-manifest-overrides.yml \
    > $PWD/$MANIFEST_NAME.yml
fi

echo manifest written to $PWD/$MANIFEST_NAME.yml
