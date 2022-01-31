#!/bin/sh

# We require Bash but for portability we'd rather not use /bin/bash or
# /usr/bin/env in the shebang, hence this hack.
if [ "x$BASH_VERSION" = "x" ]
then
    exec bash "$0" "$@"
fi

# set -e
# [ "$UID" -eq 0 ] || { echo "This script must be run as root."; exit 1; }


PAS=$'[ \033[32;1mPASS\033[0m ] '
ERR=$'[ \033[31;1mFAIL\033[0m ] '
WAR=$'[ \033[33;1mWARN\033[0m ] '
INF="[ INFO ] "
# ------------------------------------------------------------------------------
#+UTILITIES

_err()
{ # All errors go to stderr.
    printf "[%s]: %s\n" "$(date +%s.%3N)" "$1"
}

_msg()
{ # Default message to stdout.
    printf "[%s]: %s\n" "$(date +%s.%3N)" "$1"
}

_debug()
{
    if [ "${DEBUG}" = '1' ]; then
        printf "[%s]: %s\n" "$(date +%s.%3N)" "$1"
    fi
}

# Return true if user answered yes, false otherwise.
# $1: The prompt question.
prompt_yes_no() {
    while true; do
        read -rp "$1" yn
        case $yn in
            [Yy]*) return 0;;
            [Nn]*) return 1;;
            *) _msg "Please answer yes or no."
        esac
    done
}

welcome()
{
    cat<<"EOF"

 _______________________  |  _ |_  _  _ _ _|_ _  _         
|O O O O O O O O O O O O| |_(_||_)(_)| (_| | (_)| \/       
|O O O O O O 1 O O O O O|                         /        
|O O O O O O O O O O O O|  /\    _|_ _  _ _  _ _|_. _  _   
|O O O O O O O O O O O O| /~~\|_| | (_)| | |(_| | |(_)| |  
|O O 1 O O O O O 1 O 1 O|  _                               
|O O O O O O O O O O O O| (  _ |   _|_. _  _  _            
|O O O 1 O O O O O O O O| _)(_)||_| | |(_)| |_)    
|O O O O O O O O O O O O|
 -----------------------  info@labsolns.com

This script installs LIMS*Nucleus on your system

http://www.labsolns.com

EOF
    echo -n "Press return to continue..."
    read -r
}

query()
{
    echo Enter IP address:
    read IPADDRESS
    
    echo Maximum number of plates per plate set:
    read MAXNUMPLATES
}

updatesys()
{
    sudo DEBIAN_FRONTEND=noninteractive apt-get --assume-yes update
    sudo DEBIAN_FRONTEND=noninteractive apt-get --assume-yes upgrade
    sudo DEBIAN_FRONTEND=noninteractive apt-get  --assume-yes install gnupg git nscd postgresql  postgresql-contrib nano
}


guixinstall()
{
    wget 'https://sv.gnu.org/people/viewgpg.php?user_id=15145' -qO - | sudo -i gpg --import -
    wget 'https://sv.gnu.org/people/viewgpg.php?user_id=127547' -qO - | sudo -i gpg --import -

    git clone --depth 1 https://github.com/mbcladwell/ln11.git 
    git clone --depth 1 https://github.com/mbcladwell/limsn.git 

    sudo ./limsn/scripts/guix-install-mod.sh

  ## using guile-3.0.2
    guix install glibc-utf8-locales guile-dbi gnuplot
    source /home/admin/.guix-profile/etc/profile
    sudo guix install glibc-utf8-locales
    export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"
             
    guix package --install-from-file=/home/admin/ln11/artanis52.scm
    source /home/admin/.guix-profile/etc/profile

    mkdir /tmp/limsn
    mkdir /tmp/limsn/tmp
    mkdir /tmp/limsn/tmp/cache
    
    mkdir /home/admin/.configure
    mkdir /home/admin/.configure/limsn
    cp /home/admin/limsn/limsn/conf/artanis.conf /home/admin/.configure/limsn

    sudo sed -i "s/host.name = 127.0.0.1/host.name = $IPADDRESS/" /home/admin/.configure/limsn/artanis.conf
    ## must modify ENTRY now, not artanis.conf
    sudo sed -i "s/maxnumplates = 100/maxnumplates = $MAXNUMPLATES/"  /home/admin/limsn/limsn/ENTRY

    
    source /home/admin/.guix-profile/etc/profile     
     export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"    
}

initdb()
{
    _msg "configuring db"

    ## note this must be in separate script:
##    /home/admin/ln10/install-lnpg.sh

source /home/admin/.guix-profile/etc/profile 
    export LC_ALL="C"
  
  ##  sudo chmod -R a=rwx /home/admin/ln10
    sudo service postgresql stop
    sudo sed -i 's/host[ ]*all[ ]*all[ ]*127.0.0.1\/32[ ]*md5/host    all        all             127.0.0.1\/32        trust/' /etc/postgresql/11/main/pg_hba.conf
    sudo sed -i 's/\#listen_addresses =/listen_addresses =/'  /etc/postgresql/11/main/postgresql.conf
    sudo service postgresql start
    
    psql -U postgres -h 127.0.0.1 postgres -a -f /home/admin/limsn/limsn/postgres/initdba.sql
    psql -U postgres -h 127.0.0.1 lndb -a -f /home/admin/limsn/limsn/postgres/initdbb.sql
    psql -U ln_admin -h 127.0.0.1 -d lndb -a -f /home/admin/limsn/limsn/postgres/create-db.sql
    psql -U ln_admin -h 127.0.0.1 -d lndb -a -f /home/admin/limsn/limsn/postgres/example-data.sql   

 
    
}

main()
{
    local tmp_path
    welcome
    export DEBIAN_FRONTEND=noninteractive 
    _msg "Starting installation ($(date))"

    query
    updatesys
    guixinstall
    initdb  
    
    _msg "${INF}cleaning up ${tmp_path}"
    rm -r "${tmp_path}"

    _msg "${PAS}LIMS*Nucleus has successfully been installed!"

    # Required to source /etc/profile in desktop environments.
    _msg "${INF}Run 'nohup ~/run-limsn.sh &' to start the server in detached mode."
 }

main "$@"

