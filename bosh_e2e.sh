#!/bin/bash
bosh delete deployment --force cephfs-bosh-release
bosh delete release cephfs-bosh-release --force
bosh create release --force
bosh upload release
bosh -n deploy
bosh ssh --gateway_host 192.168.50.4 --gateway_user vcap --strict_host_key_checking=no cephfs/0 --default_password c1oudc0w
