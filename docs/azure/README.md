# Running a node on Microsoft Azure

## Azure setup

There is also a [Docker<>Azure ACI integration](https://docs.docker.com/cloud/aci-integration/) using docker context and the strategy is consequently similar to the one above.
However, Azure made it easier by removing the need for using their CLI nor generating credentials. In short, the whole [AWS CLI Setup](#aws-cli-setup) section boils down to:

```bash
docker login azure
```

However, it may be convenient to still install the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) for later manipulations.

We are almost done with Azure config. You just need to [create a Resource group](https://portal.azure.com/?quickstart=true#create/Microsoft.ResourceGroup) for the nodes and chose an appropriate region for your application.

If you installed the cli, just run:

```bash
az configure --defaults location=francecentral
az group create --name starknet-nodes
```

## Cloud deployment

### TL;DR copy/paste

```bash
docker context create aci starknet-aci
docker context use starknet-aci
docker volume create goerli-data --storage-account starknetnodes
docker volume create mainnet-data --storage-account starknetnodes
curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/docker-compose.yml -o docker-compose.yml
curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/docs/azure/docker-compose.azure.yml -o docker-compose.azure.yml
docker compose -f docker-compose.yml -f docs/azure/docker-compose.azure.yml up
```

### Detailed story

The `docker volume` command creates [File shares](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-introduction).
The [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview) (`starknetnodes`) is created if it does not exist. These volumes are then used in the `docker-compose.azure.yml` azure overriding configuration.

When running `docker compose up`, the `aci` context creates [Azure Container Instances](https://azure.microsoft.com/en-us/products/container-instances).
Eventually, the commands are:

- create a docker aci context: `docker context create aci <chose a context name`>
  - use the above created resource group
- `docker context use <context name>`
  - or pass the `--context <context name>` to every following commands
- create volumes:
  - `docker volume create goerli-data --storage-account <storage account name>`
  - `docker volume create mainnet-data --storage-account <storage account name>`
- execute `docker compose --project-name <chose a name project name> -f docker-compose.yml -f docs/azure/docker-compose.azure.yml up`

You can then retrieve the node urls using :

```bash
docker ps
```

You can then check that the node are running using curl:

```bash
curl $(docker ps --format json | jq '.[] | select( .ID | contains("goerli") ) | .Ports[0]' -r | cut -d "-" -f 1) \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_GOERLI
curl $(docker ps --format json | jq '.[] | select( .ID | contains("mainnet") ) | .Ports[0]' -r | cut -d "-" -f 1) \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_MAIN
```

## Monitoring

You can find info about your deployment and containers in the Resource group's page.

## Cleaning

To delete your nodes and clean everything, just run:

```bash
docker context use starknet-aci
docker compose down
docker volume rm starknetnodes/goerli-data
docker volume rm starknetnodes/mainnet-data
docker context use default
docker context rm starknet-aci
```
