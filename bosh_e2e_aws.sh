#!/bin/bash
bosh delete deployment --force cephfs-bosh-release
bosh delete release cephfs-bosh-release --force
bosh create release --force
bosh upload release
bosh -n deploy
say "done"
bosh ssh --gateway_host 52.72.95.180 --gateway_user vcap --strict_host_key_checking=no cephfs/0 --default_password c1oudc0w
