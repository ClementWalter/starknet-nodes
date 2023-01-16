#/bin/bash

sudo yum update
sudo yum search docker
sudo yum info docker
yes | sudo yum install docker
sudo usermod -a -G docker ec2-user
id ec2-user
newgrp docker
sudo yum install python3-pip
sudo pip3 install docker-compose # with root access
sudo systemctl enable docker.service
sudo systemctl start docker.service

pip3 install boto3
echo "export PATHFINDER_ETHEREUM_API_URL_GOERLI=https://goerli.infura.io/v3/${INFURA_KEY}" >> .bashrc
echo "export PATHFINDER_ETHEREUM_API_URL_MAINNET=https://mainnet.infura.io/v3/${INFURA_KEY}" >> .bashrc
exec $SHELL

mkdir data
mkdir data/goerli
mkdir data/mainnet
mkdir data/testnet2
mkdir backup
mkdir backup/goerli
mkdir backup/mainnet
mkdir backup/testnet2

curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/docker-compose.yml -o docker-compose.yml
curl https://raw.githubusercontent.com/ClementWalter/starknet-nodes/main/backup/node_backup.py -o node_backup.py

crontab -e
0 0 * * * /usr/bin/python3 /home/ec2-user/node_backup.py

nohup docker-compose up > nodes.out &
