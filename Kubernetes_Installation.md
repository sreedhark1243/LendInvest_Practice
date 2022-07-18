The intention of this file is to create a multi master kubernetes cluster on the ubuntu machines.
Pre-requisites:
i) 3 masters nodes, 2 workers nodes and one HA proxy LB node.
ii) required previleges & network connectivity such as root as we need to install the packages online.
iii) enough CPU, memory & storage


1) HA LB Installation:
------------------------------------------------
i) log in as root
sudo -i

ii) install and update with required packages:
-------------------------------------------------
sudo apt-get update && sudo apt-get upgrade -y

iii) Install haproxy
-----------------------------------------------
sudo apt-get install haproxy -y

iv) edit the haproxy configure with the masternode backends 
-----------------------------------------------------------
vi /etc/haproxy/haproxy.cfg
frontend fe-apiserver
     bind 0.0.0.0:6443
     mode tcp
     option tcplog
     default_backend be-apiserver

backend be-apiserver
     mode tcp
     option tcplog
     option tcp-check
     balance roundrobin
     default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100

            server master1 10.0.3.177:6443 check
            server master2 10.0.1.231:6443 check
            server master3 10.0.2.113:6443 check

v) restart the haproxy
----------------------------------------
systemctl restart haproxy
systemctl status haproxy

vi) to check whther 6443 is listening on not
----------------------------------------
nc -v localhost 6443

2) Install kubeadm kubelet and docker on all the master and worker machines
----------------------------------------------------------------------------
i) update the packages
sudo apt-get update

ii) swap diabling is required to install the docker
-----------------------------------------------------------------------
swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

iii) install docker
------------------------------------------------------------------------
apt-get install docker

iv) create the daemon set file for using the overlay network
------------------------------------------------------------------------
cat <<EOF | sudo tee /etc/docker/daemon.json
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF

v) restart docker and enable docker service on boot strap
--------------------------------------------------------------------------
systemctl restart docker
systemctl enable docker.service


Install kubeadm and kubelet
---------------------------------------------------------------------------------------------------------------------

i) Installing the initial requirements with the following commands.
-------------------------------------------------------------------------------
apt-get update && apt-get install -y apt-transport-https curl ca-certificates gnupg-agent software-properties-common

ii) Add Docker’s official GPG key
-----------------------------------------------------------------------------------
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

iii) Create and update the below file for debian packages
------------------------------------------------------------------------------------
cat <<EOF >/etc/apt/sources.list.d/kubernates.list
deb https://apt.kubernates.io/ kubernates-xenial main
EOF

iv) Update the packages
--------------------------------------------------------
apt-get update

v) add the repository
------------------------------------------------------------------------------
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

vi) Install Kubelet, kubectl and kubeadm
-------------------------------------------------------------------------------
sudo apt-get install -qy kubelet kubectl kubeadm

v) Reload Daemon
--------------------------
systemctl daemon-reload

vi) start the kubelet service to use kubectl
-----------------------------------------------
systemctl start kubelet

vii) enable kubelet services
---------------------------------------------------
systemctl enable kubelet.service



Additional Checks for any errors
---------------------------------------------------
route -n

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF


*****************************************************************************************************************
3) Bootstraping the cluster to join Loadbalancer:
*****************************************************************************************************************
i) run this on first master node as a root user, the Ip&port is belongs to HA LB, The control plane is exposed via load balancer IP, it going to create a controlplane server and kubeconfig file
--------------------------------------------------------------------------------------------------------
sudo kubeadm init --control-plane-endpoint 10.1.0.197:6443 --upload-certs --ignore-preflight-errors=all


a) The above command will generate the below output. It is so important as it consists of tokens for master and worker nodes to join the cluster
------------------------------------------------------------------------------------------------------------------------------------------------

######################################################################################################################################
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=$HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 10.1.0.197:6443 --token kl6qpa.22fqt1t8xhs7kvz9 \
        --discovery-token-ca-cert-hash sha256:8102a333a975c62de85222cab61f516c5daab6476d97511c6c890f66796d3ca7 \
        --control-plane --certificate-key 6e924a3b92fba9ff14a8613fd47066112844d854651f2134a430c5d89aa27b07

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.1.0.197:6443 --token kl6qpa.22fqt1t8xhs7kvz9 \
        --discovery-token-ca-cert-hash sha256:8102a333a975c62de85222cab61f516c5daab6476d97511c6c890f66796d3ca7
######################################################################################################################################

b) IF token is expired to join the worker nodes run this commnad
------------------------------------------------------------------
kubeadm token create --print-join-command

ii) Join the other two of the masters to join the cluster.  Run the below on other two master nodes as root
---------------------------------------------------------------------------------------------------------------
 kubeadm join 10.1.0.197:6443 --token kl6qpa.22fqt1t8xhs7kvz9 \
        --discovery-token-ca-cert-hash sha256:8102a333a975c62de85222cab61f516c5daab6476d97511c6c890f66796d3ca7 \
        --control-plane --certificate-key 6e924a3b92fba9ff14a8613fd47066112844d854651f2134a430c5d89aa27b07

iii) Run the below command as root to join the workernodes to the cluster
-----------------------------------------------------------------------------------------------------------------
kubeadm join 10.1.0.197:6443 --token kl6qpa.22fqt1t8xhs7kvz9 \
        --discovery-token-ca-cert-hash sha256:8102a333a975c62de85222cab61f516c5daab6476d97511c6c890f66796d3ca7



4) Configure Kubeconfig on loadbalancer node
Note: Its up to you if you want to use the LB node to set up kubeconfig. kubeconfig can also be setup externally on a seperate machine which has the access to load balancer node.
************************************************************************************************************************
i) Login to the LB node and switch to root

ii)create a ".kube" directory at $home 
-----------------------------------------
mkdir -p $HOME/.kube

iii) copy the admin.conf file from any of the master node to the below directory and change the permissions, this to run the kubectl commands from the LB node.
-------------------------------------------------------------------------------------------------------------
  
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


iv) To install kubectl on vms
------------------------------------
sudo snap install kubectl --classic

v) Now we can run commands using kubectl
-------------------------------------------
ex: kubectl get nodes; kubectl cluster-info

vi) now you can see none of the machines ready as there is no network installed for that Install weave net on the Master and worker nodes
----------------------------------------------------------------------------------
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"


vii) if you run the kubectl get pods -n kube-system -o wide, you can see 3 api-servers, 3-etcd, 3-controller manager, 3 schedulers


5) Deploying a pod to the cluster
*********************************************************************************************
i) create a deployment.yaml file and update with the below
-------------------------------------------------------------------

apiVersion: apps/v1
kind: Deployment
metadata:
  name: lendinvest
  labels:
    app: lendinvest
spec:
  replicas: 3
  selector:
    matchLabels:
      app: lendinvest
  template:
    metadata:
      labels:
        app: aymen-krypton
    spec:
      containers:
      - name: lendinvest
        image: dockerhandson/maven-web-app:latest
        ports:
        - containerPort: 8080

ii) create a service.yaml file and update as below
--------------------------------------------------------------------------
apiVersion: v1
kind: Service
metadata:
  name: lendinvest
spec:
  type: NodePort
  selector:
    app: aymen-krypton
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080

iii) Deploying the pods
----------------------------------------------------------------
a) creating the service

kubectl apply -f service.yaml

b) creating the app
kubectl apply -f deployment.yaml


iv) we can access the url using the nodeip:nodeport(u can find it from kubectl get svc), here in this case any master/worker ip and port, we can not use the loadbalancer ip as we used "NodePort"
-------------------------------------------------------------------------------------------------------------------------------------


