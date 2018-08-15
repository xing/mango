## Install _Docker_ on a Linux machine

```bash
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -    
sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu zesty stable"
sudo apt-get update

sudo apt-get install docker-ce
```

### Give rights to use Docker

Local user: `sudo usermod -aG docker $USER`
Jenkins user: `sudo usermod -aG docker jenkins-node`
⚠️ You will have to reboot the machine to apply the changes. `sudo reboot`

### Redirect docker storage location and increase its base size
_(Important for Linux machines, as it will try to download everything in `/etc/`, that will not work for more than 3 containers.) For more details please check [this](https://sanenthusiast.com/change-default-image-container-location-docker/) article._

Create a directory and file:

```bash
sudo systemctl stop docker
sudo mkdir /etc/systemd/system/docker.service.d
sudo touch /etc/systemd/system/docker.service.d/docker.conf
```

Add this in docker.conf (`sudo vi /etc/systemd/system/docker.service.d/docker.conf`):

```bash
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --graph="/virtual/docker" --storage-driver=devicemapper --storage-opt dm.basesize=20G
```

Reload docker:

```bash
sudo systemctl daemon-reload
sudo systemctl start docker
```

Useful [Docker cleanup commands](https://gist.github.com/bastman/5b57ddb3c11942094f8d0a97d461b430).
