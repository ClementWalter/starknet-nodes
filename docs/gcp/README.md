# Running a node on GCP

TL;DR copy/paste to run a mainnet node (require a GCP project and the [GKE API](https://console.cloud.google.com/marketplace/product/google/container.googleapis.com) enabled):

```bash
gcloud container clusters create starknet-nodes
gcloud container clusters get-credentials starknet-nodes
export $(xargs <.env)
kubectl run starknet-mainnet \
 --image=clementwalter/pathfinder-curl \
 --port=9545 \
 --env="PATHFINDER_ETHEREUM_API_URL=${PATHFINDER_ETHEREUM_API_URL_MAINNET}" \
 --command -- /bin/bash -c 'curl https://pathfinder-starknet-node-backup.s3.eu-west-3.amazonaws.com/mainnet/mainnet.sqlite --output /usr/share/pathfinder/data/mainnet.sqlite && pathfinder'
kubectl expose pod starknet-mainnet --port=9545 --target-port=9545 --type=LoadBalancer
```

## GCP Setup

We use the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) to deploy the nodes.

If you have already a gcloud project, you can simply use it. Otherwise, or if prefer, you will need to create one:

```bash
gcloud projects create <unique project id>
gcloud config set project <unique project id>
```

Then, we set the region and zone where we want to deploy (see [regions/zones](https://cloud.google.com/compute/docs/regions-zones)).
For example:

```bash
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-b
```

## Deployment

You first need to load then env variables defined in the .env file. For example: `export $(xargs <.env)`.

We use GKE to run the nodes. First, create a cluster:

```bash
gcloud container clusters create starknet-nodes
gcloud container clusters get-credentials starknet-nodes
```

Then the following command will pop a mainnet node (note that only the `PATHFINDER_ETHEREUM_API_URL_MAINNET` makes this node a mainnet one, the other "mainnet" are just naming):

```bash
kubectl run starknet-mainnet \
 --image=clementwalter/pathfinder-curl \
 --port=9545 \
 --env="PATHFINDER_ETHEREUM_API_URL=${PATHFINDER_ETHEREUM_API_URL_MAINNET}" \
 --command -- /bin/bash -c 'curl https://pathfinder-starknet-node-backup.s3.eu-west-3.amazonaws.com/mainnet/mainnet.sqlite --output /usr/share/pathfinder/data/mainnet.sqlite && pathfinder'
kubectl expose pod starknet-mainnet --port=9545 --target-port=9545 --type=LoadBalancer
```

You can then retrieve the node urls using :

```bash
kubectl get services
```

You can eventually then check that the node are running using curl:

```bash
curl $(kubectl get service starknet-goerli --output=json | jq ".status.loadBalancer.ingress[0].ip" | tr -d '"'):9545 \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_GOERLI
curl $(kubectl get service starknet-mainnet --output=json | jq ".status.loadBalancer.ingress[0].ip" | tr -d '"'):9545 \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_MAIN
```

## Monitoring

You can find info about your deployment and containers in the [Kubernetes cluster page](https://console.cloud.google.com/kubernetes/list/overview)

## Cleaning

To delete your nodes and clean everything, just run:

```bash
kubectl delete pods --all
kubectl delete services --all
```
