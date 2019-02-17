# Project nginxSetup

## Getting Started
Our goal is an easy install and setup of webhosting. Including SSL.
Support OS like Debian, Ubuntu and centos

## How to get

    git clone https://github.com/TirsvadCMS-Bashscripts/nginxSetup.git
    cd nginxSetup

### You maybe first have to get git
* On centos

        yum install git

* On Debian and ubuntu

        apt-get install git

## How to use
Install nginx

    bash nginxSetup.sh install

Add a domain with SSL connection

    bash nginxSetup.sh add --domain example.com --email admin@example.com

## Contributing
Please read [CONTRIBUTING.md](https://github.com/TirsvadCMS-Bashscripts/nginx_setup/blob/master/CONTRIBUTING.md)

## Versioning
We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/TirsvadCMS-Bashscripts/nginx_setup/tags).