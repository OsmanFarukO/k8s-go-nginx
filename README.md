# Hello turkai from @name

Simpe hello webapp writen with golang and using nginx as a load balancer.

## CI/CD explained

CI/CD designed for automate build and push docker images (goapp, nginx) to registry.gitlab.com/osmanfaruko/ repository.
When the commit pushed to repository working 3 stage in gitlab-ci (dep, test, build) .

### dep stage

In this stage we build app/main.go file for create so light docker images

``` bash
GOOS=linux GOARCH=386 go build -o ./app/main ./app/main.go
```

### test stage

In this stage we test our main project that using app/main_test.go file.

```bash
go test ./app -v
```

### build stage

After dep and test stages we ready to build new docker images. For this we are using docker:latest image and docker:dind service.
When the job success we updated goapp:latest and nginx:latest images in registry and add new 2 images with commit id tag.

Example result when build stage done:
```bash
registry.gitlab.com/osmanfaruko/turkai-ex/goapp:latest   (updated)
registry.gitlab.com/osmanfaruko/turkai-ex/goapp:47cc5826 (added)
registry.gitlab.com/osmanfaruko/turkai-ex/goapp:a16d68d0 (previous image)
```

## Docker-Compose explaine

Docker-compose environment designed for build and run app and nginx services in host.

Our main app running on 11130 internal port (no access from host). And nginx service running 80:80 and 443:443 ports.

When the system run with 

```bash
docker-compose up -d
```
command we can get request with 

```bash
curl http://localhost/example-osman
```

this command. When the command execute nginx will proxy this request to mainapp in internal network. And the result is:

```bash
Hello Turkai from example-osman
```
You can see more details in doc_docker file.

## Kubernetes explained

Kubernetes environment designed for deploy (go-app , nginx-lb) services in cluster and auto-scale nginx-lb service when need.

Before we run cluster first create it with using minikube:

```bash
minikube start --mount --mount-string="./k8s/nginx:/turkai/nginx"
```

With this command we started kubernetes cluster with mountpoint for to use nginx/default.conf in node. We will use defined mountpoint in k8s/nginx-env.yaml file.

```yaml

spec:
    containers:
        volumeMounts:
            - mountPath: /etc/nginx/conf.d/default.conf
              name: nginx-vol0
              readOnly: true
    .
    .
    .
    volumes:
        - hostPath:
            path: /turkai/nginx/default.conf
            type: File
          name: nginx-vol0
```

After succeed this command we can use kubectl in this created minikube cluster.

First we need to get access registry.gitlab.com for get mainapp and nginx images. For do this you must have docker login credentials.

```bash
cat ~/.docker/config.json
```
command output must have registry.gitlab.com in auths block.

```bash
{
	"auths": {
		"registry.gitlab.com": {
			"auth": "XXXXXXXX=="
		}
	}
}
```
After then you can create kubernetes secret with named 'regcred'

```bash
kubectl create secret generic regcred \
	--from-file=.dockerconfigjson=~/.docker/config.json \
	--type=kubernetes.io/dockerconfigjson
```
We will use this secret in k8s/nginx-env.yaml and k8s/go-env.yaml file.

```yaml
    imagePullSecrets:
        - name: regcred
```

After this we can apply our deployments and services in this cluster.

```bash
kubectl apply -f k8s/go-env.yml
```

With this command we applied main go app to cluster. This file include 1 Deployment named backend with 1 replica and 1 Service named go-app. After applied we can see what happened with this commands.

```bash
kubectl describe pods backend-747d9c4ff6-q5qjf
```
End of the command output:

```bash
Events:
  Type    Reason          Age                 From               Message
  ----    ------          ----                ----               -------
  Normal  SandboxChanged  16m (x3 over 16m)   kubelet, minikube  Pod sandbox changed, it will be killed and re-created.
  Normal  Pulling         16m (x2 over 131m)  kubelet, minikube  Pulling image "registry.gitlab.com/osmanfaruko/turkai-ex/goapp:latest"
  Normal  Pulled          15m (x2 over 131m)  kubelet, minikube  Successfully pulled image "registry.gitlab.com/osmanfaruko/turkai-ex/goapp:latest"
  Normal  Created         15m (x2 over 131m)  kubelet, minikube  Created container go-app
  Normal  Started         15m (x2 over 131m)  kubelet, minikube  Started container go-app
```

As you can see pod (backend-747d9c4ff6-q5qjf) created well. Pulled our image with success and started go-app service.

Now lets apply nginx-lb service and deployment.

```bash
kubectl apply -f k8s/nginx-env.yml
```

After applied nginx-lb service with above command we see there is 1 replica.

```bash
kubectl describe replicasets nginx-lb-fb68ff67c
```

Output:
```bash
Annotations:    deployment.kubernetes.io/desired-replicas: 1
                deployment.kubernetes.io/max-replicas: 1
                deployment.kubernetes.io/revision: 1
Controlled By:  Deployment/nginx-lb
Replicas:       1 current / 1 desired
Pods Status:    1 Running / 0 Waiting / 0 Succeeded / 0 Failed
```
Now our 2 pods and service running as well.

```bash
kubectl get pods,svc
```
Output:
```bash
NAME                           READY   STATUS    RESTARTS   AGE
pod/backend-747d9c4ff6-q5qjf   1/1     Running   1          139m
pod/nginx-lb-fb68ff67c-2gv95   1/1     Running   2          138m

NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/go-app       ClusterIP      10.111.216.8   <none>        11130/TCP      139m
service/kubernetes   ClusterIP      10.96.0.1      <none>        443/TCP        140m
service/nginx-lb     LoadBalancer   10.96.88.197   <pending>     80:31966/TCP   139m

```

After then lets port-forward from host to nginx-lb service to see result.

```bash
kubectl port-forward service/nginx-lb 8080:80
```

When the command above is running in new tab you can type:

```bash
curl http://localhost:8080/example-osman
```

Output:

```bash
Hello Turkai from example-osman
```

Our app running very well as you can see. Now lets auto-scale nginx-lb with using k8s/nginx-as.yml file.

```bash
kubectl apply -f k8s/nginx-as.yml
```

The nginx-as.yml file designed like this:

```yaml
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-lb
  minReplicas: 4
  maxReplicas: 10
```

This means targeted nginx-lb Deployment will have minimum 4 and maximum 10 replica. After then we can see the nginx-lb service incress 4 replica.

```bash
kubectl get pods,svc
```

Output:

```bash
NAME                           READY   STATUS    RESTARTS   AGE
pod/backend-747d9c4ff6-q5qjf   1/1     Running   1          149m
pod/nginx-lb-fb68ff67c-2gv95   1/1     Running   2          149m
pod/nginx-lb-fb68ff67c-46nn9   1/1     Running   2          149m
pod/nginx-lb-fb68ff67c-hwd9s   1/1     Running   1          149m
pod/nginx-lb-fb68ff67c-vcjtk   1/1     Running   1          149m

NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/go-app       ClusterIP      10.111.216.8   <none>        11130/TCP      149m
service/kubernetes   ClusterIP      10.96.0.1      <none>        443/TCP        150m
service/nginx-lb     LoadBalancer   10.96.88.197   <pending>     80:31966/TCP   149m
```
As we can see 3 nginx-lb pod created. When the metrics values happened it can create 6 more nginx-lb pod.

## Kubernetes resource show with bash and python

I create very simple ways to show our cluster resources with bash and python scripts.

```bash
./bash-rs/k8s_resources.sh
```

Command will output:

```bash
:: Node capacity :: 
Capacity:
  cpu:                8
  ephemeral-storage:  122030736Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             16258908Ki
  pods:               110
:: Node allocatable capacity ::
Allocatable:
  cpu:                8
  ephemeral-storage:  122030736Ki
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             16258908Ki
  pods:               110
:: Node allocated resources :: 
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests    Limits
  --------           --------    ------
  cpu                850m (10%)  100m (1%)
  memory             190Mi (1%)  390Mi (2%)
  ephemeral-storage  0 (0%)      0 (0%)
  hugepages-1Gi      0 (0%)      0 (0%)
  hugepages-2Mi      0 (0%)      0 (0%)
```

And for execute python 

```bash
virtualenv -p python3 turkai.env

source turkai.env/bin/activate

pip install requirements.txt

python k8s_pods.py
```

Output is:

```bash
Listing pods with their IPs:
172.18.0.8	default	backend-747d9c4ff6-q5qjf
172.18.0.6	default	nginx-lb-fb68ff67c-2gv95
172.18.0.7	default	nginx-lb-fb68ff67c-46nn9
172.18.0.4	default	nginx-lb-fb68ff67c-hwd9s
172.18.0.3	default	nginx-lb-fb68ff67c-vcjtk
172.18.0.5	kube-system	coredns-66bff467f8-c7fsd
172.18.0.2	kube-system	coredns-66bff467f8-qdfr6
172.17.0.2	kube-system	etcd-minikube
172.17.0.2	kube-system	kindnet-7k6lj
172.17.0.2	kube-system	kube-apiserver-minikube
172.17.0.2	kube-system	kube-controller-manager-minikube
172.17.0.2	kube-system	kube-proxy-2n8tw
172.17.0.2	kube-system	kube-scheduler-minikube
172.17.0.2	kube-system	storage-provisioner
```