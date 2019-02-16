#!/bin/bash
set -euo pipefail

declare -r ERR_CODE=1 # Miscellaneous errors
declare -r ERR_CODE_UNKNOWN_OPTION=3
declare -r ERR_CODE_UNKNOWN_DOMAIN_NAME=9 # Could not lookup any ip adresse for domain name

# set defaults value
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 1>/dev/null 2>&1 && pwd )"
DIR_CONF="$( cd $DIR"/conf/" && pwd )"
BASE_PATH="/var/www/"
SITES_AVAILABLE_PATH="/etc/nginx/sites-available/"
SITES_ENABLE_PATH="/etc/nginx/sites-enabled/"

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

# Get requiered tools
case $OS in
    "Debian GNU/Linux")
        [ ! $(which nslookup &>/dev/null) ] && apt-get -qq install dnsutils >/dev/null
        [ ! $(which certbot &>/dev/null) ] && apt-get -qq install python-certbot-nginx >/dev/null
        ;;
    "Ubuntu")
        [ ! $(which nslookup &>/dev/null) ] && apt-get -qq install dnsutils >/dev/null
        [ ! $(which certbot &>/dev/null) ] && apt-get -qq install python-certbot-nginx >/dev/null
        ;;
    "CentOS Linux")
        case $OS_VER in
        7)
            yum -y install epel-release
            ;;
        esac
        [ ! $(which nslookup &>/dev/null) ] && yum -y install bind-utils
        [ ! $(which certbot &>/dev/null) ] && yum -y install mod_ssl python-certbot-nginx
        [ ! $(which firewalld &>/dev/null) ] && {
            [[ ! $(firewall-cmd --list-service | grep -w "http") ]] && firewall-cmd --add-service http
            [[ ! $(firewall-cmd --list-service | grep -w "https") ]] && firewall-cmd --add-service https
            firewall-cmd --runtime-to-permanent
        }
        ;;
    *)
        echo "$OS is not supported" 1>&2
        exit 1
        ;;
esac

usage() {
    echo "Usage:"
    echo "    nginxSetup -h                                Display this help message."
    echo "    nginxSetup install                           Install Nginx."
    echo "    nginxSetup add --domain example.com --email admin@example.com    # Hosting a website with ssl"
    echo "    --baseWwwPath /var/www/                      default /var/www/"
    echo "    --domainRootPath example.com/"
    echo "    --publicPath public_html/"
    exit 0
}

install_nginx() {
    case $OS in
    "Debian GNU/Linux")
        apt-get -qq install nginx >/dev/null
        ;;
    "Ubuntu")
        apt-get -qq install nginx >/dev/null
        ;;
    "CentOS Linux")
        case $OS_VER in
        7)
            yum -y install nginx
            ;;
        *)
            echo "$OS $OS_VER is not supported" 1>&2; exit 1;;
        esac
        ;;
    * )
        echo "$OS is not supported" 1>&2; exit 1;;
    esac
    systemctl start nginx
}


function ssl_certificate {
    # Required no prosses listen to port 80
    # $1 required a hostname
    # s2 required a email adress
    [ ! -d "/var/www/letsencrypt/" ] && mkdir -p /var/www/letsencrypt/
    eval "certbot --nginx --redirect --keep-until-expiring --non-interactive --agree-tos -m $2 -d $1" 1>/dev/null
}

add_domain() {
    # check for arguments that is required
    [ -z ${DOMAIN:-} ] && {
        echo "missing --domain domane_name"
        exit 1
    } || {
        TOPDOMAIN=$(echo $DOMAIN | cut -d / -f 3 | cut -d : -f 1 | rev | cut -d . -f 1,2 | rev)
        [ -z $(dig +short $DOMAIN) ] && { echo "$DOMAIN could not be lookup" 1>&2; exit $ERR_CODE_UNKNOWN_DOMAIN_NAME; }
        [ -z ${SSL_EMAIL:-} ] && { echo "Email not given but required for SSL certificate" 1>&2; exit 1; }
        [ -z ${DOMAIN_ROOT_PATH:-} ] && DOMAIN_ROOT_PATH="$BASE_PATH$TOPDOMAIN/$DOMAIN/"
        [ -z ${PUBLIC_PATH:-} ] && PUBLIC_PATH="public_html/"
        # create directory and add path to nginx.conf (Needed in Centos)
        [ ! -d $SITES_AVAILABLE_PATH ] && {
            mkdir -p $SITES_AVAILABLE_PATH
            [ ! -d $SITES_ENABLE_PATH ] && mkdir -p $SITES_ENABLE_PATH
            sed -i "/^    include \/etc\/nginx\/conf.d/ a include $SITES_ENABLE_PATH*;" /etc/nginx/nginx.conf
            sed -i '/^    server {/i <start of serverblock>' /etc/nginx/nginx.conf
            sed -i '/# Settings for a TLS enabled server./i <end of serverblock>' /etc/nginx/nginx.conf
            sed -i "/<start of serverblock>/,/<end of serverblock>/d" /etc/nginx/nginx.conf
        }
        # delete the defaul page
        [ -e /etc/nginx/sites-enabled/default ] && rm /etc/nginx/sites-enabled/default
        # check if domain already exists
        [ -e $SITES_AVAILABLE_PATH$DOMAIN ] && { echo "This domain already exists." 1>&2; exit 1; }
        ### check if directory exists or not
        [ ! -d $DOMAIN_ROOT_PATH$PUBLIC_PATH ] && mkdir -p $DOMAIN_ROOT_PATH$PUBLIC_PATH
        cp $DIR_CONF/index.html $DOMAIN_ROOT_PATH$PUBLIC_PATH
        cp $DIR_CONF/nginx_domian_ssl_pre.conf $SITES_AVAILABLE_PATH$DOMAIN
        sed -i -e 's/\$DOMAIN/'"${DOMAIN}"'/g' $SITES_AVAILABLE_PATH$DOMAIN
        ln -s $SITES_AVAILABLE_PATH$DOMAIN $SITES_ENABLE_PATH$DOMAIN
        systemctl reload nginx
        ssl_certificate $DOMAIN $SSL_EMAIL
        cp $DIR_CONF/nginx_domian_ssl.conf $SITES_AVAILABLE_PATH$DOMAIN
        sed -i -e "s/\$DOMAIN/$(echo $DOMAIN | sed -e 's/[\/&]/\\&/g')/g" $SITES_AVAILABLE_PATH$DOMAIN
        sed -i -e "s/\$ROOT_DIR/$(echo $DOMAIN_ROOT_PATH | sed -e 's/[\/&]/\\&/g')/g" $SITES_AVAILABLE_PATH$DOMAIN
        sed -i -e "s/\$PUBLIC_PATH/$(echo $PUBLIC_PATH | sed -e 's/[\/&]/\\&/g')/g" $SITES_AVAILABLE_PATH$DOMAIN
        systemctl reload nginx
    }
}

while [ $# -gt 0 ]
do
    case $1 in
        -h|--help)
            usage; exit 0;;
        --email)
            shift; SSL_EMAIL=$1;;
        --domain)
            shift; DOMAIN=$1;;
        --baseWwwPath)
            shift; BASE_PATH=$1;;
        --domainRootPath)
            shift; DOMAIN_ROOT_PATH=$1;;
        --publicPath)
            shift; PUBLIC_PATH=$1;;
        --)
            shift; break;;
        --*)
            echo "$0: error - unrecognized option $1" 1>&2; exit $ERR_CODE_UNKNOWN_OPTION;;
        -*)
            echo "$0: error - unrecognized option $1" 1>&2; exit $ERR_CODE_UNKNOWN_OPTION;;
        *)
            subcommand=$1;;
    esac
    shift
done

case "$subcommand" in
    install)
        echo "installing nginx"; install_nginx;;
    add)
        echo "installing adding domain"; add_domain;;
    *)
        echo "$0: error - unrecognized command option $subcommand" 1>&2; exit $ERR_CODE_UNKNOWN_OPTION;;
esac