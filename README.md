# Welcome to Starknet-nodes

This repo aims at delivering deployment scripts for running prod-grade Starknet nodes.

## Docker compose

The [docker-compose.yml](./docker-compose.yml) file embeds everything to run or deploy goerli and mainnet nodes in one command.
It uses env variables defined in the `.env` file that you need to create from the `example.env` and populate with Ethereum RPC endpoints.

```bash
cp example.env .env
# replace the value(s) of PATHFINDER_ETHEREUM_API_URL by the HTTP URL(s) pointing to your Ethereum node's endpoint
```

By default, `docker compose up` will run both a mainnet and a goerli node. If you want to run only one service, you can specify it after the `up`:

```bash
docker compose up # run both mainnet and goerli
docker compose up starknet-mainnet # run mainnet only
docker compose up starknet-goerli # run goerli only
```

To retrieve the logs, use `docker-compose logs -f`.

To retrieve the URLs of the nodes, use `docker compose ps`.

The mainnet node runs on port 9546 while the goerli one runs on port 9545. You can check this by calling the `starknet_chainId` method:

```bash
curl '0.0.0.0:9545' \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed
# {"jsonrpc":"2.0","result":"0x534e5f474f45524c49","id":0}
echo 0x534e5f474f45524c49 | xxd -rp
# SN_GOERLI
curl '0.0.0.0:9546' \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed
# {"jsonrpc":"2.0","result":"0x534e5f4d41494e","id":0}
echo 0x534e5f4d41494e | xxd -rp
# SN_MAIN
```

## Cloud deployment

Docker has built-in integrations with [AWS](https://docs.docker.com/cloud/ecs-integration/) and [Azure](https://docs.docker.com/cloud/aci-integration/) using `docker context`.
For these provider, the above-mentioned `docker compose` commands work out-of-the-box **when no project-name** is specified.

More details are given in the dedicated pages:

- for AWS: [docs/aws/README.md](./docs/aws/README.md)
- for Azure: [docs/azure/README.md](./docs/azure/README.md)
- for GCP: [docs/gcp/README.md](./docs/gcp/README.md)

## Backup

The RPC node works with a built-in sqlite database that can be populated using daily snapshots stored in a S3 bucket.
Hence the container's command starts with a `curl` to the appropriate file. You can safely remove this command if you want to run the node from scratch or if you have another backup mechanism.
