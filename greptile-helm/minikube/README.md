## Deploying greptile locally with minikube

### Prerequisites
  - docker + docker desktop
  - minikube
  - kubectl 
  - helm

For MacOS: `brew install docker minikube kubernetes-cli helm`

### Steps to run greptile
1. Ensure that `kubectl` is pointing at minikube

```bash
kubectl config current-context   # should print "minikube"
```

2. Start a fresh minikube cluster
```bash
minikube delete                   # nuke any existing cluster
minikube start \
  --memory 8192 --cpus 4 \
  --disk-size 20g
```

3. Load container images into the cluster
Minikube’s runtime can’t reach your private AWS ECR registry directly, so you pre-seed the VM with images
You will need to load in 11 images with this command
`minikube image load "IMG_NAME"`
Alternatively, you can run the script `greptile-helm/load-images-to-minikube.sh`

3. Prepare your `values-minikube.yaml`
You can use values-minikube.example to start

4. Add helm dependencies
`helm dependency update`

5. Run helm install
`helm install greptile . -f values-minikube.yaml`

6. After it completes you can inspect it via `minikube dashboard`

7. Access the web frontend here `minikube service greptile-web --url`


## Creating Docker Hub secret
1. Obtain a token from Greptile to be able to pull Greptile images
2. With the provided token, create a secret in kubernetes
```
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=greptileai \
  --docker-password=<token> \
  --docker-email=tobias@greptile.com
```
3. Make sure that the values.yaml references the `regcred` secret

Bring up hatchet via: `helm install hatchet-stack hatchet/hatchet-stack -f hatchet-values.yaml`

db migrations only need to be enabled for the installation