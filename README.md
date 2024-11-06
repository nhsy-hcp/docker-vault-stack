# docker-vault-stack

## Description
This repository contains a docker compose stack with the following services:
- grafana
- loki
- prometheus
- promtail
- vault enterprise with raft backend

## Pre-requisites
Install `taskfile` with the following command:
```shell
  brew install go-task
```

Create a `.env` file in the root folder with the following content:
```shell
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_LICENSE=
```

## Usage
[Taskfile.yml](Taskfile.yml) contains automation commands to manage the stack.

Launch the docker compose stack with the following command:
```bash
task up
```

Initialise vault and unseal.
```shell
task init
task unseal
```

Add the VAULT_TOKEN to the `.env` file and load.
```shell
source .env
vault token lookup
```

## Post initialisation
```shell
source .env
task up unseal
```

Navigate to the following urls:
- http://localhost:3000/ - Grafana
- http://localhost:9090/ - Prometheus
- http://localhost:8200/ - Vault

Execute vault benchmark to test the performance of the vault and generate vault metrics.
(requires `vault-benchmark` cli tool)
```shell
vault namespace create vault-benchmark
task benchmark
```