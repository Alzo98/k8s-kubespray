#!/bin/bash

###############################################
#   TITRE: install_nfs.sh 
#   AUTEUR: Alioune
#   VERSION: 1.0
#   MODIFIE:
#   
#   DESCRIPTION:  installation de nfs pour nos pv kubernetes
###############################################

# VARIABLES ###################################


IP_RANGE=$(dig +short autohaprox | sed s/".[0-9]*$"/.0/g)


# FUNCTIONS ###################################

prepare_directories(){
    sudo mkdir -p /srv/wordpress/{db,files}
    sudo chmod 777 -R /srv/
}

install_nfs(){
    sudo apt-get install -y nfs-kernel-server 2>&1 > /dev/null
}

set_nfs(){
    sudo echo "/srv/wordpress/db ${IP_RANGE}/24(rw,sync,no_root_squash,no_subtree_check)">/etc/exports
    sudo echo "/srv/wordpress/files ${IP_RANGE}/24(rw,sync,no_root_squash,no_subtree_check)">>/etc/exports
}

run_nfs(){
    sudo systemctl restart nfs-server rpcbind
    sudo exportfs -a
}


# Let's Go !! #################################

prepare_directories
install_nfs
set_nfs
run_nfs
