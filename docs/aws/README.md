# Running a node on AWS

## AWS CLI setup

To deploy programmatically to AWS, you first need to install and configure the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
If you are okay with this step, just make sure that your configured credentials have the appropriate [policy](https://github.com/ClementWalter/starknet-nodes/blob/ea49f1a6da8950c4628e89b1e9b3c63ccf1023bd/docs/aws/policy.json) and jump to the next section.

It is recommended not to use your own root user credentials with the CLI.
Instead, you should create an specific policy for the task and then an IAM User granted only these accesses. Eventually, you can generate credentials for this _user_ and create a _profile_ in the CLI for using them. Ouch. But we've got you covered!

### TL;DR copy/paste

```bash
curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/docs/aws/policy.json -o policy-document.json
aws iam create-policy --policy-name docker-ecs-context --policy-document 'file://policy-document.json' > policy.json
rm policy-document.json
aws iam create-group --group-name docker-ecs-users
aws iam attach-group-policy --group-name docker-ecs-users --policy-arn `cat policy.json | jq ".Policy.Arn" -r`
aws iam create-user --user-name docker-ecs-user
aws iam add-user-to-group --group-name docker-ecs-users --user-name docker-ecs-user
aws iam create-access-key --user-name docker-ecs-user > access_key.json
aws configure --profile docker-ecs
```

### Details

- create an AWS policy using this [policy file](https://github.com/ClementWalter/starknet-nodes/blob/ea49f1a6da8950c4628e89b1e9b3c63ccf1023bd/docs/aws/policy.json)

  - either using the [AWS console](https://us-east-1.console.aws.amazon.com/iam/home#/policies$new?step=edit)
  - or with the cli:

  ```bash
  aws iam create-policy --policy-name docker-ecs-context --policy-document 'file://docs/aws/policy.json' > policy.json
  ```

- create a AWS user group and add it the above created policy

  - either with the [AWS console](https://us-east-1.console.aws.amazon.com/iamv2/home?region=eu-west-1#/groups/create)
  - or with the cli:

  ```bash
  aws iam create-group --group-name docker-ecs-users
  aws iam attach-group-policy --group-name docker-ecs-users --policy-arn `cat policy.json | jq ".Policy.Arn" -r`
  ```

- create an AWS User, select only "Access key - Programmatic access", and add it to the above created group

  - either using the [AWS console](https://us-east-1.console.aws.amazon.com/iam/home#/users$new?step=details)
  - or with the cli:

  ```bash
  aws iam create-user --user-name docker-ecs-user
  aws iam add-user-to-group --group-name docker-ecs-users --user-name docker-ecs-user
  aws iam create-access-key --user-name docker-ecs-user > access_key.json
  ```

- create an AWS profile for deploying the node using the generated credentials

  ```bash
  aws configure --profile docker-ecs
  ```

## CloudFormation deployment

Now that the hard part is done, let us focus on the easy one: deploying the [eqlabs/pathfinder docker image](https://hub.docker.com/r/eqlabs/pathfinder) to AWS.

Indeed, we use the [Docker<>ECS integration](https://docs.docker.com/cloud/ecs-integration/) to deploy a whole [CloudFormation stack](https://aws.amazon.com/cloudformation/) right from a simple `docker-compose.yml` file. This deployment only requires to change the [docker context](https://docs.docker.com/engine/context/working-with-contexts/) to use ECS.

So basically a simple `docker compose up` is enough.
Which means that you need to have docker compose installed on your machine. Refer to [their doc](https://docs.docker.com/get-docker/) for your own configuration.

### TL;DR copy/paste

```bash
curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/docker-compose.yml -o docker-compose.yml
curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/docs/aws/docker-compose.aws.yml -o docker-compose.aws.yml
docker context create ecs starknet-ecs
docker context use starknet-ecs
docker compose -f docker-compose.yml -f docker-compose.aws.yml up
```

### Detailed story

The creation of the `docker context` lets "update" all the docker commands to use AWS services in a pre-defined manner. For instance, it creates a [AWS Cloudformation](https://aws.amazon.com/cloudformation/) stack with the following main components:

- [Elastic File Systems](https://aws.amazon.com/efs/) for the volumes
- an [ECS cluster](https://docs.aws.amazon.com/AmazonECS/latest/userguide/clusters.html) with goerli and mainnet services and tasks.
- [AWS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/userguide/what-is-fargate.html) to run the containers

The deployed stack can be monitored on the [AWS CloudFormation home page](https://eu-west-3.console.aws.amazon.com/cloudformation/home).
All the `aws cloudformation` commands are available for managing the stack.
Indeed, you can also use the `docker compose convert` tool to generate the corresponding Stack configuration and eventually use the aws cli instead:

```bash
docker compose convert > stack.yaml
aws cloudformation deploy --template-file stack.yml --stack-name starknet-nodes --capabilities CAPABILITY_IAM --profile docker-ecs
```

Eventually, deploying the nodes requires:

- to create a docker ecs context: `docker context create ecs <chose a context name`>
  - for example, `docker context create ecs starknet-ecs`
  - use the above created profile
- and use it: `docker context use <context name>`
  - or pass the `--context <context name>` to every following commands
- to execute `docker compose --project-name <chose a name visible in aws console> -f docker-compose.yml -f docs/aws/docker-compose.aws.yml up`
  - for example, `docker compose --project-name starknet-nodes -f docker-compose.yml -f docs/aws/docker-compose.aws.yml up`
  - ignore the `WARNING services.scale: unsupported attribute`
  - the `--project-name` option lets define the name of the stack but creates bugs for later use of `docker compose logs/down/etc.` so I don't recommend to use it for now.

The created endpoints can be found in the ECS Cluster page:

- Cluster > Services > Networking > DNS names

or directly using docker compose:

```bash
docker compose ps
```

You can export those URLs easily for later user with the `--format json` option:

```bash
docker compose ps --format json > nodes.json
```

You can then check that the nodes are running using for example `curl`:

```bash
curl `docker compose ps --format json | jq ".[0].Publishers[0].URL" -r` \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_GOERLI
curl `docker compose ps --format json | jq ".[1].Publishers[0].URL" -r` \
  -H 'content-type: application/json' \
  --data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
  --compressed | jq .result | xxd -rp
# SN_MAIN
```

## Troubleshooting

The backup download time before the node actually starts can be quite long. If the node keeps restarting because of health check, you can extend the [health check grace period](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecs/update-service.html).

In the following snippet, we put 3000s because it should be enough time to download ~100Gb at relatively low rate of ~33Mb/s:

```bash
aws ecs list-services --cluster starknet-nodes | \
  jq '.serviceArns[] | select (. | contains ("goerli") )' -r | cut -d '/' -f 3 | xargs -L1 \
aws ecs update-service \
  --cluster starknet-nodes \
  --health-check-grace-period-seconds 3000 \
  --service $1
```

## Monitoring

The deployed stack can be monitored on the [AWS CloudFormation home page](https://eu-west-3.console.aws.amazon.com/cloudformation/home).
All the `aws cloudformation` commands are available for managing the stack.
The `docker compose logs` command will output the logs otherwise found in CloudWatch.

## Cleaning

To delete your nodes and clean everything, just run:

```bash
docker context use starknet-ecs
docker compose down
docker context use default
docker context rm starknet-ecs
aws efs describe-file-systems | jq ".FileSystems[].FileSystemId" | xargs -L1 aws efs delete-file-system --file-system-id $1
export POLICY_ARN=$(aws iam list-attached-group-policies --group-name docker-ecs-users | jq ".AttachedPolicies[0].PolicyArn" -r)
aws iam detach-group-policy --group-nam docker-ecs-users --policy-arn $POLICY_ARN
aws iam delete-policy --policy-arn $POLICY_ARN
aws iam remove-user-from-group --group-name docker-ecs-users --user docker-ecs-user
aws iam delete-group --group-name docker-ecs-users
aws iam delete-access-key --user-name docker-ecs-user --access-key-id $(cat access_key.json | jq ".AccessKey.AccessKeyId" -r)
aws iam delete-user --user-name docker-ecs-user
```
