#/bin/bash
set -euo pipefail

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    OS_VER=$VERSION_ID
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
fi

usage() {
    echo "Usage:"
    echo "    nginxSetup -h                                Display this help message."
    echo "    nginxSetup install                           Install Nginx."
    echo "    nginxSetup create_webdomain --domain example.com --email admin@example.com    # Hosting a website with ssl"
    echo "    --baseWwwPath                                follow by /var/www/"
    echo "    --domainRootPath                             "
    echo "    --publicPath"
    exit 0
}

install_nginx() {
    case $OS in
    "Debian GNU/Linux")
        apt-get install nginx 1>/dev/null
        ;;
    "Ubuntu")
        apt-get install nginx 1>/dev/null
        ;;
    "CentOS Linux")
        case $OS_VER in
        7)
            yum -y install epel-release 1>/dev/null
            yum -y install nginx 1>/dev/null
            ;;
        esac
        ;;
    * )
        echo "$OS is not supported" 1>&2
        exit 1
        ;;
    esac

    systemctl start nginx
}

while [ $# -gt 0 ]
do
    case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        --email)
            shift
            echo "eamil is $1"
            ;;
        --)
            shift;
            break;;
        --*)
            echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
        -*)
            echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
        *)
            subcommand=$1
            printf "\nsubcommand is : $1 \n"
            break;;
    esac
    echo "$1"
    shift
done


case "$subcommand" in
    install)
        install_nginx
        ;;
    create_webdomain)
        echo "doing nothing yet"
        ;;
esac