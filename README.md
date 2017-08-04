# Building foreman RPM packages using docker container

In case you don't have docker installed, please add the following repo:
```
[docker]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
```

Afterwards, install docker with the following command:
```sh
yum install docker-engine
```

Start and enable the docker service:
```sh
systemctl start docker
systemctl enable docker
```

Next step is to pull the docker container from the Docker Hub which will later be used as a basis for the RPM build container:
```sh
docker pull centos
```

For using the foreman_docker_build script you will also need to install rpm-build and ruby:
```sh
yum install rpm-build ruby git
```

Change to the foreman_docker_build and start building your foreman package
```sh
cd foreman_docker_build
./build_foreman_packages.sh -n foreman -b 1.15-stable
```

That's all. After the build is ready, the RPMs are located in the directory "foreman/RPM".

## Available options

 -n <name>           Specify the name of the package you want to build. Identical with the git repo name 
 
 -b <branch>         Branch or tag you want to build from the package (must be available in git repo - of course)
                     Default: master
                     
 -p <packaging_name> Name of the package within foreman-packaging (like, foreman-tasks is the name but 
                     "rubygem-foreman-tasks is the name within foreman-packakging. If not given, same as name

