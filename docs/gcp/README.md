# Running a node on GCP

## GCP setup

There is no native Docker<>GCP integration and the usual way to deploy a containerized stack to GCP is to use the [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine).

You first need to install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install).

If you have already a gcloud project, you can simply use it. Otherwise — or if you prefer — you need to create one:

```bash
gcloud projects create <unique project id>
gcloud config set project <unique project id>
```

Then, we set for the project the region and zone we want to deploy in (see [regions/zones](https://cloud.google.com/compute/docs/regions-zones)).
For example:

```bash
gcloud projects create starknet-nodes --name Starknet-nodes
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-b
```

## Cloud deployment

### TL;DR copy/paste

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
kubectl run starknet-goerli \
 --image=clementwalter/pathfinder-curl \
 --port=9545 \
 --env="PATHFINDER_ETHEREUM_API_URL=${PATHFINDER_ETHEREUM_API_URL_GOERLI}" \
 --command -- /bin/bash -c 'curl https://pathfinder-starknet-node-backup.s3.eu-west-3.amazonaws.com/goerli/goerli.sqlite --output /usr/share/pathfinder/data/goerli.sqlite && pathfinder'
kubectl expose pod starknet-goerli --port=9545 --target-port=9545 --type=LoadBalancer
```

### Detailed story

We first create a Kubernetes cluster on GCP. You can check all the options using `gcloud container clusters create --help`. Especially, by default, the cluster uses 3 nodes (param `--num-nodes=NUM_NODES; default=3`).

Then we log into this cluster using the gcloud cli to have the `kubectl` command working directly on GCP.
Depending on the versions of gcloud used, you may need to follow [this doc](https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke) to be able to login correctly.
We also export all the env variables defined in a `.env` file (where we put the `PATHFINDER_ETHEREUM_API_URL_MAINNET` and `PATHFINDER_ETHEREUM_API_URL_GOERLI` definition).

Eventually, `kubectl run` lets define the pods to run, and `kubectl expose` expose the pods (the _starknet nodes_).

You can then retrieve the node urls using :

```bash
kubectl get services
```

and eventually check that the node are running using curl:

```bash
curl $(kubectl get service starknet-goerli --output=json | jq ".status.loadBalancer.ingress[0].ip" -r):9545 \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_GOERLI
curl $(kubectl get service starknet-mainnet --output=json | jq ".status.loadBalancer.ingress[0].ip" -r):9545 \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_MAIN
```

## Troubleshooting

You can connect to your cluster using [Cloud Shell](https://console.cloud.google.com/cloudshelleditor), from browser or using the gcloud cli:

```bash
gcloud cloud-shell ssh
```

It may happen that the initial backup download fails. This does not prevent the node to start but can make it several days to be ready. So if it happened,
just `ssh` into the container and re-run the download command:

```bash
kubectl exec -it starknet-goerli -c starknet-goerli -- sh
curl https://pathfinder-starknet-node-backup.s3.eu-west-3.amazonaws.com/goerli/goerli.sqlite --output /usr/share/pathfinder/data/goerli.sqlite
```

## Monitoring

You can find info about your deployment and containers in the [Kubernetes cluster page](https://console.cloud.google.com/kubernetes/list/overview)

## Cleaning

To delete your nodes and clean everything, just run:

```bash
kubectl delete pods --all
kubectl delete services --all
gcloud container clusters delete starknet-nodes
gcloud projects delete starknet-nodes
```
