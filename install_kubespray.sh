#!/bin/bash

# clone et install de kubespray $1



# get some variables ##########################################################

if [[ "$1" == "y" ]];then
INGRESS="NGINX"
fi

IP_HAPROXY=$(dig +short autohaprox)
IP_KMASTER=$(dig +short autokmaster)



# Functions ##################################################################


prepare_kubespray(){

echo
echo "## 1. Git clone kubepsray"
git clone https://github.com/kubernetes-sigs/kubespray.git
chown -R vagrant /home/vagrant/kubespray
cd /home/vagrant/kubespray
git checkout release-2.24


echo
echo "## 2. Install requirements"
pip3 install --quiet -r requirements.txt

echo
echo "## 3. ANSIBLE | copy sample inventory"
cp -rfp inventory/sample inventory/mykub

echo
echo "## 4. ANSIBLE | change inventory"
cat /etc/hosts | grep autokm | awk '{print $2" ansible_host="$1" ip="$1" etcd_member_name=etcd"NR}'>inventory/mykub/inventory.ini
cat /etc/hosts | grep autokn | awk '{print $2" ansible_host="$1" ip="$1}'>>inventory/mykub/inventory.ini

echo "[kube-master]">>inventory/mykub/inventory.ini
cat /etc/hosts | grep autokm | awk '{print $2}'>>inventory/mykub/inventory.ini

echo "[etcd]">>inventory/mykub/inventory.ini
cat /etc/hosts | grep autokm | awk '{print $2}'>>inventory/mykub/inventory.ini

echo "[kube-node]">>inventory/mykub/inventory.ini
cat /etc/hosts | grep autokn | awk '{print $2}'>>inventory/mykub/inventory.ini

echo "[calico-rr]">>inventory/mykub/inventory.ini
echo "[k8s-cluster:children]">>inventory/mykub/inventory.ini
echo "kube-master">>inventory/mykub/inventory.ini
echo "kube-node">>inventory/mykub/inventory.ini
echo "calico-rr">>inventory/mykub/inventory.ini


if [[ "$INGRESS" == "NGINX" ]]; then
echo
echo "## 5.1 ANSIBLE | active ingress controller nginx"
sudo chmod 700 kubespray/inventory/*
sudo sed -i s/"ingress_nginx_enabled: false"/"ingress_nginx_enabled: true"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sudo sed -i s/"# ingress_nginx_host_network: false"/"# ingress_nginx_host_network: true"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sudo sed -i s/"# ingress_nginx_nodeselector:"/"ingress_nginx_nodeselector:"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sudo sed -i s/"#   kubernetes.io\/os: \"linux\""/"  kubernetes.io\/os: \"linux\""/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sudo sed -i s/"# ingress_nginx_namespace: \"ingress-nginx\""/"ingress_nginx_namespace: \"ingress-nginx\""/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sudo sed -i s/"# ingress_nginx_insecure_port: 80"/"ingress_nginx_insecure_port: 80"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sudo sed -i s/"# ingress_nginx_secure_port: 443"/"ingress_nginx_secure_port: 443"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml

fi


echo
echo "## 5.2 ANSIBLE | active external LB"
sudo sed -i s/"## apiserver_loadbalancer_domain_name: \"elb.some.domain\""/"apiserver_loadbalancer_domain_name: \"autoelb.kub\""/g inventory/mykub/group_vars/all/all.yml
sudo sed -i s/"# loadbalancer_apiserver:"/"loadbalancer_apiserver:"/g inventory/mykub/group_vars/all/all.yml
sudo sed -i s/"#   address: 1.2.3.4"/"  address: ${IP_HAPROXY}"/g inventory/mykub/group_vars/all/all.yml
sudo sed -i s/"#   port: 1234"/"  port: 6443"/g inventory/mykub/group_vars/all/all.yml

echo
echo "## 5.3 ANSIBLE | change CNI to kube-router"
sudo sed -i s/"kube_network_plugin: calico"/"kube_network_plugin: kube-router"/g inventory/mykub/group_vars/k8s_cluster/k8s-cluster.yml

}


create_ssh_for_kubespray(){
echo 
echo "## 6. SSH | ssh private key and push public key"
sudo -u vagrant chmod 700 /home/vagrant/.ssh
sudo -u vagrant ssh-keygen -b 2048 -t rsa -f /home/vagrant/.ssh/id_rsa -q -N ''
for srv in $(cat /etc/hosts | grep autok | awk '{print $2}');do
     sudo -u vagrant cat /home/vagrant/.ssh/id_rsa.pub | sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=no vagrant@$srv -T 'tee -a >> /home/vagrant/.ssh/authorized_keys'
done
}





run_kubespray(){

echo
echo "## 7. ANSIBLE | Run kubepsray"
sudo su - vagrant bash -c "cd kubespray && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/mykub/inventory.ini -b -u vagrant cluster.yml"

}

install_kubectl(){

echo
echo "## 8. KUBECTL | Install"
sudo apt-get update -qq 2>&1 >/dev/null
sudo apt-get install -qq -y apt-transport-https 2>&1 >/dev/null
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg 
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq 2>&1 >/dev/null
sudo apt-get install -qq -y kubectl 2>&1 >/dev/null
sudo mkdir -p /home/vagrant/.kube
sudo mkdir -p /root/.kube
sudo chown -R vagrant /home/vagrant/.kube

echo
echo "## 9. KUBECTL | copy cert"
ssh -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@${IP_KMASTER} "sudo cat /etc/kubernetes/admin.conf" >/home/vagrant/.kube/config
cp /home/vagrant/.kube/config /root/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
sudo chown vagrant:vagrant /root/.kube/config
sudo chmod 600 /home/vagrant/.kube/config
}




# Let's go ##########################################################################################

prepare_kubespray
create_ssh_for_kubespray
run_kubespray
install_kubectl
