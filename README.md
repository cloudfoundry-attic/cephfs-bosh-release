# cephfs-bosh-release

This bosh release includes all of the requisite parts to provide ceph file system volume mounts to a Cloud Foundry deployment.

It comprises three jobs: cephfs, cephbroker and cephdriver.

The instructions below will help you to install cephfs-bosh-release into your cloud foundry deployment

## Installation
### Pre-Requisites
- You will need Go 1.7 or later to install this project.  
- it is recommended to install [direnv](https://github.com/direnv/direnv) to manage your GOPATH correctly
- you will need (somewhere) a running [ceph-authtool](http://docs.ceph.com/docs/hammer/man/8/ceph-authtool/) in order to create a ceph keyring file.  This tool only runs on linux, so you may need to use your VM or container technology of choice.
- you will need to install Cloud Foundry, or start from an existing CF deployment.  If you are starting from scratch, the article [Overview of Deploying Cloud Foundry](https://docs.cloudfoundry.org/deploying/index.html) provides detailed instructions.

### Uploading to bosh

    ```bash
    cd ~/workspace
    git clone https://github.com/cloudfoundry-incubator/cephfs-bosh-release.git
    cd cephfs-bosh-release
    direnv allow
    ./scripts/update
    git submodule init && git submodule update
    bosh -n create-release
    bosh -n upload-release
    ```

### Creating a keyring file
#### ceph-keyring.yml
- in a shell with `ceph-authtool` installed, type the following commands to generate a keyring file:

    ```bash
    ceph-authtool -C -n client.admin --gen-key keyring
    ceph-authtool -n client.admin --cap mds 'allow' --cap osd 'allow *' --cap mon 'allow *' keyring
    ceph-authtool -l keyring
    ```

- this should spit out a keyring description that looks something like this:

    ```
      [osd.0]
              key = SOMETHING==
      [osd.1]
              key = SOMETHING==
      [osd.2]
              key = SOMETHING==
      [client.admin]
              key = SOMETHING==
              auid = 0
              caps mds = "allow"
              caps mon = "allow *"
              caps osd = "allow *"
    ```

- create a new `ceph-keyring.yml` file and place the following contents in it:

    ```yml
    ---
    cephfs-keyring: |
      <YOUR KEYRING DESCRIPTION>
    ```

### To deploy cephfs 

- deploy to the same bosh director you use for Cloud Foundry.
    ```
    cd ~/workspace/cephfs-bosh-release
    bosh -n -d cephfs deploy manifest/cephfs.yml --vars-file=ceph-keyring.yml 
    ```

### To deploy cephdriver and cephbroker

- Determine the IP address of your ceph cluster vm:
    ```bash
    bosh -d cephfs instances | grep cephfs | awk '{print $4}'
    ```

- edit `ceph-keyring.yml` to add the following line at the bottom:
    ```yml
    cephfs-mds: <CEPH CLISTER IP>:6789
    ```

- now redeploy Cloud Foundry using the ceph ops file from this release:
    ```bash
    cd ~/workspace/cf-deployment
    bosh -d cf deploy cf.yml \
    -v deployment-vars.yml \ 
    -v ceph-keyring.yml \
    -o ../cephfs-bosh-release/operations/deploy-ceph-broker-and-install-driver.yml
    ```
    
- bosh will generate a broker password for you automatically. You can find the password for use in broker registration via the `bosh interpolate` command:
    ```bash
    bosh int deployment-vars.yml --path /cephfs-broker-password
    ```
    
## Testing

### Register cephbroker
- type the following: 
    ```bash
    cf create-service-broker cephbroker admin <BROKER_PASSWORD> http://ceph-broker.YOUR.DOMAIN.com
    cf enable-service-access ceph-service
    ```

### Create a ceph volume service
- type the following: 
    ```
    cf create-service ceph-service ceph-plan myVolume
    ```

### Deploy the pora test app, bind it to your service and start the app
* type the following: 
    ```bash
    cd src/code.cloudfoundry.org/persi-acceptance-tests/assets/pora
    
    cf push pora --no-start
    
    cf bind-service pora myVolume
    
    cf start pora
    ```
    
> ####Bind Parameters####
> * **mount:** By default, volumes are mounted into the application container in an arbitrarily named folder under /var/vcap/data.  If you prefer to mount your directory to some specific path where your application expects it, you can control the container mount path by specifying the `mount` option.  The resulting bind command would look something like 
> ``` cf bind-service pora myVolume -c '{"mount":"/var/my/path"}'```

### Test the app to make sure that it can access your volume
* to check if the app is running, `curl http://pora.YOUR.DOMAIN.com` should return the instance index for your app
* to check if the app can access the shared volume `curl http://pora.YOUR.DOMAIN.com/write` writes a file to the share and then reads it back out again.

## Troubleshooting
If you have trouble getting this release to operate properly, try consulting the [Volume Services Troubleshooting Page](https://github.com/cloudfoundry-incubator/volman/blob/master/TROUBLESHOOTING.md)

