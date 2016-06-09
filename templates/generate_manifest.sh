#!/bin/bash
#generate_manifest.sh
/usr/bin/expect <<EOD
spawn bosh logout
expect eof

spawn bosh target $3
expect "Your username:"
send "$4\n"
expect "password:"
send "$5\n"
expect eof

spawn bosh login
expect "Your username:"
send "$4\n"
expect "password:"
send "$5\n"
expect eof
EOD



director_uuid=$(bosh status --uuid)
echo "Director:${director_uuid}"

usage () {
    echo "Usage: generate_manifest.sh bosh-lite|aws [cephfs*|cephdriver]"
    echo " * default"
    exit 1
}

if [[  "$1" != "bosh-lite" && "$1" != "aws" ]]
  then
    usage
fi

DIRECTOR_YML=$(cat <<END_HEREDOC
name: $2
director_uuid: ${director_uuid}
releases:
    - name: cephfs
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
  - release: cephfs
    name: cephfs
  - release: cephfs
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
  - {release: cephfs, name: cephdriver}
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

#director_uuid=$(bosh status --uuid)




bosh deployment $MANIFEST_NAME.yml
