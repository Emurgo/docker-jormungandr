* [travis-ci.org (timestamped-commit tag):](https://hub.docker.com/r/emurgornd/jormungandr/) [![Build Status](https://travis-ci.com/Emurgo/docker-jormungandr.svg?branch=master)](https://travis-ci.com/Emurgo/docker-jormungandr)

# Build

Execute from repo root dir:

```
DOCKER_IMAGE_NAME=emurgornd/jormungandr
JORMUNGANDR_VERSION=0.7.5
JORMUNGANDR_COMMIT=v0.7.5 # commit/tag/branch to checkout scripts from

for target in src src-build
do
  BUILD_IMAGE=${DOCKER_IMAGE_NAME}:${target}-${JORMUNGANDR_COMMIT}
  docker build \
    -f Dockerfile.${target} \
    --build-arg JORMUNGANDR_VERSION=${JORMUNGANDR_VERSION} \
    --build-arg JORMUNGANDR_COMMIT=${JORMUNGANDR_COMMIT} \
    --cache-from ${BUILD_IMAGE} \
    -t ${BUILD_IMAGE} \
    .
done

docker build -t ${DOCKER_IMAGE_NAME}:${JORMUNGANDR_VERSION} \
  --build-arg JORMUNGANDR_VERSION=${JORMUNGANDR_VERSION} \
  --build-arg JORMUNGANDR_COMMIT=${JORMUNGANDR_COMMIT} .
```

# Run

Customize the environment in docker-compose.yaml and execute this from repo root dir:

```
docker-compose up -d
```
It will then:
* Pull the `emurgornd/jormungandr:latest` from the hub if wasn't built locally
* Bootstrap the node if the necessary files are not present in `$DATA_DIR`, which defaults to `/data` and is bind mounted from `$GIT_REPO_DIR/data`.
* Run `jormungandr` with default config file (placed in `$DATA_DIR/config.yaml`, so you can easily modify it)


You can also run it using plain docker:
```
JORMUNGANDR_VERSION=0.7.5
JORMUNGANDR_EXTRA_ARGS=--enable-explorer
JORMUNGANDR_BLOCK0_HASH=_CHANGE_ME_
PUBLIC_PORT=8300
docker run -d --name jormungandr-${JORMUNGANDR_VERSION} \
  -v $HOME/.jormungandr-${JORMUNGANDR_VERSION}:/data \
  -p $PUBLIC_PORT:8299 \
  -e PUBLIC_PORT=$PUBLIC_PORT \
  -e JORMUNGANDR_BLOCK0_HASH=$JORMUNGANDR_BLOCK0_HASH \
  -e JORMUNGANDR_EXTRA_ARGS=$JORMUNGANDR_EXTRA_ARGS \
  emurgornd/jormungandr:${JORMUNGANDR_VERSION}
```

Note that if no `$JORMUNGANDR_BLOCK0_HASH` was provided, the node will be started with the bootstrapped/generated genesis block.

# Run your own chain

## Run 1 genesis node + 1 peer trusting it

* Run the genesis-node and get it's block0 hash
```
cp -a .env-template .env
DOCKER_COMPOSE_FILE=docker-compose.yaml-standalone-chain
docker-compose -f ${DOCKER_COMPOSE_FILE} up -d genesis-node
unset JORMUNGANDR_BLOCK0_HASH; while [ -z "$JORMUNGANDR_BLOCK0_HASH" ] ; do JORMUNGANDR_BLOCK0_HASH=$(docker-compose -f ${DOCKER_COMPOSE_FILE} exec genesis-node jcli rest v0 settings get | grep ^block0Hash: | awk '{print $NF}'); sleep 0.5; done
```
* Save environment for secondary nodes
```
cat > .env <<EOF
JORMUNGANDR_BLOCK0_HASH=$JORMUNGANDR_BLOCK0_HASH
TRUSTED_PEER_ID=$(docker-compose -f ${DOCKER_COMPOSE_FILE} exec genesis-node grep public_id /data/config.yaml | awk '{print $NF}' | sed 's|"||g')
EOF
```
* Load environment and run a secondary node trusting genesis-node
```
source .env
docker-compose -f ${DOCKER_COMPOSE_FILE} up -d trusted-peers
```

Now you should be able to connect to your genesis-node REST API through http://localhost:8443 and use the genesis info you can get from container's log:
```
docker-compose -f ${DOCKER_COMPOSE_FILE} logs genesis-node | head -n22
```

## Scale nodes

NOTE: peers will only have genesis-node as trusted peer, they should talk each other internally tho
```
REPLICAS=2
docker-compose -f ${DOCKER_COMPOSE_FILE} up -d --scale trusted-peers=${REPLICAS}
```

## Destroy deployment
```
DOCKER_COMPOSE_FILE=docker-compose.yaml-standalone-chain
docker-compose -f ${DOCKER_COMPOSE_FILE} down -v
# remove genesis' block0 bin and all the configs for genesis-node
#rm -rf data
```

## Destroy only secondary nodes
```
docker-compose -f ${DOCKER_COMPOSE_FILE} kill trusted-peers
docker-compose -f ${DOCKER_COMPOSE_FILE} rm -f trusted-peers
```

## Environment variables

| VARIABLE                   | Description                                                                  |
| -------------------------- | ---------------------------------------------------------------------------- |
| JORMUNGANDR_EXTRA_ARGS     | Extra arguments to pass to the daemon                                        |
| JORMUNGANDR_ARGS           | If provided, will take precedence over any default                           |
| JORMUNGANDR_BLOCK0_HASH    | Genesis block to use instead of local bootstrapped genesis                   |
| NODE_ID                    | If provided, will be used as `public_id`, else, it will be auto-generated    |
| PUBLIC_ADDRESS             | Force daemon to publish this address. If not provided, will be guessed. If set to `internal`, it will use `eth0`'s.       |
| PUBLIC_PORT                | Port to be published to the internet. If not provided, defaults to 8299      |
| TRUSTED_PEER_ADDRESS       | If provided, will be used as *single* (multiple peers not supported yet) peer address. Needs `TRUSTED_PEER_ID` to be set aswell |
| TRUSTED_PEER_ID            | Same case that for `TRUSTED_PEER_ADDRESS`                                    |
| DATA_DIR                   | Data dir to be used inside the container. Defaults to `/data`                |
| DEBUG                      | Sets entrypoint bash script in debug mode                                    |

## Checking logs

Execute from repo root dir:

```
docker-compose logs -f
```

## Using jcli

Execute from repo root dir:
```
docker-compose exec jormungandr bash -c 'jcli rest v0 node stats get --host $JCLI_HOST'
# or execute an interactive shell
docker-compose exec jormungandr bash
```

# Debug

If you use docker-compose to bring the whole thing up, the entrypoint is bind mounted to easily debug things without having to rebuild the image.
