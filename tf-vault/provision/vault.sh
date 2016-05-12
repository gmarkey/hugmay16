#!/usr/bin/env bash

. ~/environment

sudo yum -y install gettext unzip screen

#export s3_bucket_name=${s3_bucket_name}
#export aws_access_key=${aws_access_key}
#export aws_secret_key=${aws_secret_key}

envsubst < vault.hcl.tmpl > vault.hcl
curl -Lo vault.zip https://releases.hashicorp.com/vault/0.5.2/vault_0.5.2_linux_amd64.zip
unzip vault.zip
sudo setcap cap_ipc_lock=+ep vault
screen -dm ./vault server --config=vault.hcl
