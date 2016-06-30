# cephfs-bosh-release

*Tested on bosh-lite and AWS...but only actually works on AWS*

## Overview

This bosh release comprises three jobs: cephfs, cephbroker and cephdriver.  These are typically deployed separately, and the driver job is typically folded into a diego release using the -d option during diego manifest generation, since it must be colocated on the Diego cell.

## Installation
### Pre-Requisites
```
bosh target <your bosh director url>
```

For Bosh-Lite:
```
bosh upload stemcell https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent --skip-if-exists
```
NB: As of today, bosh lite deployment has permissions issues with volume mounts, and is not fully operational, so *caveat emptor* and all that.

For AWS:
```
bosh upload stemcell https://bosh.io/d/stemcells/bosh-aws-xen-ubuntu-trusty-go_agent --skip-if-exists
```

### To Install
Git clone the repo and create a bosh release from it:
```
git clone https://github.com/cloudfoundry-incubator/cephfs-bosh-release.git
bosh create release
```
NB: Accept the default name for the release (cephfs-bosh-release)

Upload the release to your bosh director.
```
bosh upload release
```

#### To deploy Cephfs

Generate the manifest for your environment.  Check your `bosh target` is correct.
```
./templates/generate_manifest.sh bosh-lite|aws
```

##### To deploy Cephdriver

The driver must be colocated with the Diego cell in order to work correctly in a CF/Diego environment.  For details on how to create a drivers stub and include the cephdriver job in the Diego cell VM, [follow these instructions](https://github.com/cloudfoundry/diego-release/blob/develop/examples/aws/OPTIONAL.md#fill-in-drivers-stub).
```
./templates/generate_manifest.sh bosh-lite|aws cephdriver
```

## Verify the install

#### Cephfs

SSH onto the bosh release VM

`bosh ssh --gateway_host <your bosh director ip> --gateway_user vcap --strict_host_key_checking=no cephfs/0`

Check the health of the ceph-cluster

`ceph -s`

which should report something like this:-

```
cluster c0162a84-1d21-46a2-8a8e-4507f6ec707f
 health HEALTH_OK
 monmap e1: 1 mons at {f4fb115c-1ec1-4788-8a14-8c76f98a9545=10.244.8.2:6789/0}
        election epoch 2, quorum 0 f4fb115c-1ec1-4788-8a14-8c76f98a9545
 mdsmap e5: 1/1/1 up {0=15557bd5-7880-46d0-b33d-fac8b420a65f=up:active}
 osdmap e15: 3 osds: 3 up, 3 in
        flags sortbitwise
  pgmap v20: 320 pgs, 3 pools, 1960 bytes data, 20 objects
        51265 MB used, 151 GB / 206 GB avail
             320 active+clean
```

#### Cephdriver

SSH onto the bosh release VM

`bosh ssh --gateway_host <your bosh director ip> --gateway_user vcap --strict_host_key_checking=no cell_z1/0`

Check the health of the cephdriver service

`sudo monit summary`

which should report something like this:-

```
The Monit daemon 5.2.4 uptime: 15h 24m

Process 'cephdriver'                running
System 'system_50b08287-989a-4e81-8c0e-9c22d5cc809e' running
```

#### Cephbroker

SSH onto the bosh release VM

`bosh ssh --gateway_host <your bosh director ip> --gateway_user vcap --strict_host_key_checking=no cell_z1/0`

Check the health of the cephdriver service

`sudo monit summary`

which should report something like this:-

```
The Monit daemon 5.2.4 uptime: 15h 24m

Process 'cephbroker'                running
System 'system_50b08287-989a-4e81-8c0e-9c22d5cc809e' running
```

## Mount cephfs (using fuse)

Perform a quick sanity check.  In a driver or broker the same ssh session:-

```
sudo mkdir ~/mycephfs
sudo ceph-fuse -k /etc/ceph/ceph.client.admin.keyring -m <your cephfs VM ip>:6789 ~/mycephfs
```

Check the volume is mounted

`df -h`

and test the mount

```
pushd mycephfs
sudo mkdir mydir
sudo sh -c 'echo "something" > myfile'
cat myfile
```

# Development Setup
## Installing the code
After cloning this repository, you will need to run `./scripts/update` to fetch
code for all of the submodules.
## Git Secrets
The `update` script above also installs git hooks to invoke git-secrets on any
git commit.  This checks the commit to make sure that it doesn't contain any
unsafe AWS keys or passwords.  On OS X, the update script also installs git-secrets
using homebrew.  For other platforms, you will need to build and install it yourself
following the instructions in the [git-secrets README](https://github.com/awslabs/git-secrets).

Make sure to invoke `git secrets --register-aws --global` after you have installed git-secrets.

It is *not* necessary to run `git secrets --install` as the `./scripts/update` script will 
perform this step for you.

## Intellij Setup

If you use IntelliJ, configure your project to run `gofmt` and `goimports` using the following regex:-

```
(file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/ceph*/*.go||file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/volman/*.go||file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/volume_driver_cert/*.go)&&!file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/volume_driver_cert/vendor//*
```

NB: This is so that Intellij does not `go fmt` dependent packages which may result in source changes.
