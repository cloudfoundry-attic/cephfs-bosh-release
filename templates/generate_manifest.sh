#!/bin/bash
#generate_manifest.sh

usage () {
    echo "Usage: generate_manifest.sh bosh-lite|aws deployment-name [bosh-target] [bosh-user] [bosh-password]"
    echo " * default"
    exit 1
}

if [[  "$1" != "bosh-lite" && "$1" != "aws" || -z $2 ]]
  then
    usage
fi

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

DIRECTOR_YML=$(cat <<END_HEREDOC
name: $2
director_uuid: ${director_uuid}
releases:
    - name: cephfs
END_HEREDOC
)

MANIFEST_NAME=cephfs-manifest

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

echo manifest written to $PWD/$MANIFEST_NAME.yml
