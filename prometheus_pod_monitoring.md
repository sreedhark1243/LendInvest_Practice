1) On Docker or Kuberenetes: Best option is to opt for the docker.

i)  Run an alpine container and install prometheus. Mount present working directory to the container so that you can copy the files from container to the local present working directory.

cd C:\Kubernates\Prometheus\

docker run -it -v ${PWD}:/work -w /work alpine sh

ii) install git to ur container
apk add git

iii) create a clone of the release-0.10 inside the container
git clone --depth 1 https://github.com/prometheus-operator/kube-prometheus.git -b release-0.10 /tmp/

iv) copy the manifests folder to your present working directory.

cp -R /tmp/manifests .

v) Install the promethus pods on kubernetes cluster on your local.
a) create monitoring namespace
kubectl create -f ./manifests/setup/

b) create all the pods for prometheus, this will create the all PODS, Services, ServiceMonitors, Deploymentsfiles.
kubectl create -f ./manifests

vi) Description of important pods.

kubectl -n monitoring get pods

Kubestate metrics POD -- scraps the metrics from the pod such as CPU, Memory, Disk Space
node-exporter - all the metrics of the entire node
prometeus-operator POD -- to maintain the all the prometeus instances.

vii) enable grafana console on 3000 port and access it http://localhost:3000
kubectl -n monitoring port-forward svc/grafana 3000

username:admin
password:admin

b) There is an issue while testing the default prometheus component in the gaffana console. fix is below
kubectl get svc -n monitoring


Update the "grafana-dashboardDatasources.yaml" in the manifests folder with <url": "http://prometheus-operated.monitoring.svc:9090",>
and delete the gaffana pod running, it will auto created.

kubectl apply -f grafana-dashboardDatasources.yaml

kubectl delete pod gaffa -n monitoring

kubectl -n monitoring port-forward svc/grafana 3000

Now go to-->http://localhost:3000/datasources/edit/P1809F7CD0C75ACF3-->configuration-->datasources-->click on prometheus URL--? and go down and test.

Now 

c) Launch Prometheus Console and Here you can see the targets inside the Targets section. 

kubectl -n monitoring port-forward svc/prometheus-operated 9090

Now u can access prometheus console through http://localhost:9090/, Navigate to Status-->Dropdown menu select --->Targets. Here you can see the Status of the Pods and Nodes.


To Enable a Thridparty pod. We need to have a pod with service and exporter for the pod.

Below Heml chart commands will help to create the required components.

add repos

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update


install chart

to verify the values of the exporter 
helm show values prometheus-community/prometheus-redis-exporter > C:\Kubernates\Prometheus\helm_redis_values.yaml

Or else create a file helm_redis_values.yaml and update with the atatched file.

install the chart, to create the redis exporter, service for exporter and service monitor.


helm install redis-exporter prometheus-community/prometheus-redis-exporter -f helm_redis_values.yaml


Verify the pods, services and servicemonitors are created and running.

kubectl get pods
kubectl get svc
kubect get servicemonitors



Expose the port to the prometheus on a port. The port should be the service port of the exporter.

kubectl port-forward service/redis-exporter-prometheus-redis-exporter 9216 

Verify the the redis DB target from the prometeus console

Now u can access prometheus console through http://localhost:9090/, Navigate to Status-->Dropdown menu select --->Targets. Here you can see the Status of the Pods and Nodes.


Notes: 
1) release: prometheus is most important label as this allows promethus to find the servicemonitors in the cluster and register them it can stracping the application which is right here, Here if you can see the below yaml, in the selectors section--> app.kubernetes.io/name: grafana and spec-->endpoints--->-path: /metrics endpoints are exposed.

kubectl get servicemonitor promethues-kube-promethus-grafana -o yaml


2) exporter plays important role is exposing the custom metrics of the application. we got node exporter which got pre-installed as part of the previous installation.
