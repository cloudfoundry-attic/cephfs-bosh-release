cephfs-bosh-release
===================

*Tested on bosh-lite and AWS...but only actually works on AWS*

## Overview

This bosh release includes all of the requisite parts to provide ceph file system volume mounts to a cloudfoundry/Diego deployment.

It comprises three jobs: cephfs, cephbroker and cephdriver.  These are typically deployed to separate VMs, and the driver job must be deployed to a diego cell.  We normally incorporate the driver job into diego using the -d option during diego manifest generation.

## Installation
### Pre-Requisites
- You will need Go 1.7 or later to install this project.  
- it is recommended to install [direnv](https://github.com/direnv/direnv) to manage your GOPATH correctly
- you will need (somewhere) a running [ceph-authtool](http://docs.ceph.com/docs/hammer/man/8/ceph-authtool/) in order to create a ceph keyring file.  This tool only runs on linux, so you may need to use your VM or container technology of choice.
- you will need a Cloudfoundry/Diego deployment running on AWS.  Instructions for this setup are [here](https://github.com/cloudfoundry/diego-release/blob/develop/examples/aws/README.md).

### Fetching the code
We have a helper script to pull in all of the required submodules for this project, so we recommend these steps:
```
git clone https://github.com/cloudfoundry-incubator/cephfs-bosh-release.git
cd cephfs-bosh-release
direnv allow
./scripts/update
```

### Preparing bosh director
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

### Uploading to bosh

```
git clone https://github.com/cloudfoundry-incubator/cephfs-bosh-release.git
git submodule init && git submodule update
bosh create release
bosh upload release
```

### Creating Stub files
#### director.yml
- determine your bosh director uuid by invoking `bosh status --uuid`
- create a new `director.yml` file and place the following contents into it:

```
---
director_uuid: <your uuid>
```
#### ceph-keyring.yml
- in a shell with `ceph-authtool` installed, type the following commands to generate a keyring file:

```
ceph-authtool -C -n client.admin --gen-key keyring
ceph-authtool -n client.admin --cap mds 'allow' --cap osd 'allow *' --cap mon 'allow *' keyring
ceph-authtool -l keyring
```

- this should spit out a keyring description that looks something like this:

```
      [osd.0]
              key = REDACTED==
      [osd.1]
              key = REDACTED==
      [osd.2]
              key = REDACTED==
      [client.admin]
              key = REDACTED==
              auid = 0
              caps mds = "allow"
              caps mon = "allow *"
              caps osd = "allow *"
```
- create a new `ceph-keyring.yml` file and place the following contents in it:

```
---
properties:
  cephfs:
    client_keyring: |
      <YOUR KEYRING DESCRIPTION>
  cephbroker:
      <YOUR KEYRING DESCRIPTION AGAIN>
```
#### cf.yml
Our manifest generation scripts require the deployment manifest for your cloudfoundry deployment as an input.  If you have it, you can just use it, otherwise you can pull it from bosh:

```
bosh download manifest <your cf deplyment name> >cf.yml
```

#### creds.yml
- create a new `creds.yml` file and place the following contents in it:

```
---
credentials:
  username: <USERNAME>
  password: <PASSWORD>
```

### To deploy cephfs and cephbroker 

Generate the manifest for your environment.  Check your `bosh target` is correct.
```
./templates/generate_manifest.sh aws cf.yml ceph-keyring.yml director.yml creds.yml
bosh deployment cephfs-aws-manifest.yml
bosh deploy
```

### To deploy cephdriver THE OLD WAY :thumbsdown:
If your bosh director version is older than `259` then you will need to follow these steps. (type `bosh status` to check the version of your director)

The driver must be colocated with the Diego cell in order to work correctly in a CF/Diego environment.  
This will require you to regenerate your diego manifest with the driver job included in it, and (re)deploy Diego.
For details on how to create a drivers stub and include the cephdriver job in the Diego cell VM, [follow these instructions](https://github.com/cloudfoundry/diego-release/blob/develop/examples/aws/OPTIONAL.md#fill-in-drivers-stub).

### To deploy cephdriver THE NEW WAY :thumbsup:
If you have a new bosh director (version 259 or later) then you can deploy the driver to diego as an add-on, without changing your diego manifest.  The driver must still be colocated on the diego cell, but bosh is now capable of targeting add-ons to specific VMs using filtering.
  
- Create a new `runtime-config.yml` with the following content:
   
```yaml
---
releases:
- name: cephfs
  version: <YOUR VERSION HERE>
addons:
- name: voldrivers
  include:
    deployments: 
    - <YOUR DIEGO DEPLOYMENT NAME>
    jobs: 
    - name: rep
      release: diego
  jobs:
  - name: cephdriver
    release: cephfs
    properties: {}
```

- Set the runtime config, and redeploy diego

```bash
bosh update runtime-config runtime-config.yml
bosh download manifest <YOUR DIEGO DEPLOYMENT NAME> diego.yml
bosh -d diego.yml deploy
```

## Verify the install

#### Cephfs

SSH onto the bosh release VM

`bosh ssh --gateway_host <your bosh director ip> --gateway_user vcap --strict_host_key_checking=no cephfs/0`

Check the health of the ceph-cluster

`ceph -s`

which should report something like this:

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

which should report something like this:

```
The Monit daemon 5.2.4 uptime: 15h 24m

Process 'cephdriver'                running
System 'system_50b08287-989a-4e81-8c0e-9c22d5cc809e' running
```

#### Cephbroker

SSH onto the bosh release VM

`bosh ssh --gateway_host <your bosh director ip> --gateway_user vcap --strict_host_key_checking=no cephbroker/0`

Check the health of the cephbroker service

`sudo monit summary`

which should report something like this:

```
The Monit daemon 5.2.4 uptime: 15h 24m

Process 'cephbroker'                running
System 'system_50b08287-989a-4e81-8c0e-9c22d5cc809e' running
```

#### Manually mounting cephfs (using fuse)

You can manually mount a ceph filesystem to perform a quick sanity check.  In a driver or broker VM:

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

## Development Setup
### Installing the code
After cloning this repository, you will need to run `./scripts/update` to fetch
code for all of the submodules.
### Git Secrets
The `update` script above also installs git hooks to invoke git-secrets on any
git commit.  This checks the commit to make sure that it doesn't contain any
unsafe AWS keys or passwords.  On OS X, the update script also installs git-secrets
using homebrew.  For other platforms, you will need to build and install it yourself
following the instructions in the [git-secrets README](https://github.com/awslabs/git-secrets).

Make sure to invoke `git secrets --register-aws --global` after you have installed git-secrets.

It is *not* necessary to run `git secrets --install` as the `./scripts/update` script will 
perform this step for you.

### Intellij Setup

If you use IntelliJ, configure your project to run `gofmt` and `goimports` using the following regex:

```
(file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/ceph*/*.go||file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/volman/*.go||file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/volume_driver_cert/*.go)&&!file[cephfs-bosh-release]:src/github.com/cloudfoundry-incubator/volume_driver_cert/vendor//*
```

NB: This is so that Intellij does not `go fmt` dependent packages which may result in source changes.
