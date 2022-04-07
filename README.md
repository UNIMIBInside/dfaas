# DFaaS: Decentralized Function-as-a-Service for Federated Edge 
This repository holds DFaaS, a novel decentralized FaaS-based architecture designed to automatically and autonomously balance the traffic load across edge nodes belonging to federated Edge Computing ecosystems.

DFaaS implementation relies on an overlay peer-to-peer network and a distributed control algorithm that takes decisions on load redistribution. Although preliminary, our results confirm the feasibility of the approach, showing that the system can transparently redistribute the load across edge nodes when they become overloaded.

Our prototype is based on OpenFaaS and implements the control logic within Go P2P agents.

This research work is conducted by the INteraction and SemantIcs for Innovation with Data & Services (INSID&S) Laboratory of the University of Milano - Bicocca.

If you wish to reuse this source code, please consider citing our article describing the first prototype:

> Michele Ciavotta, Davide Motterlini, Marco Savi, Alessandro Tundo <br>
> [**DFaaS: Decentralized Function-as-a-Service for Federated Edge Computing**](https://doi.org/10.1109/CloudNet53349.2021.9657141), <br>	
> 2021 IEEE 10th International Conference on Cloud Networking (CloudNet), DOI: 10.1109/CloudNet53349.2021.9657141.

## Scenario

![Scenario](images/Scenario-crop.png)

The above figure depicts the considered network scenario. A set of geographically-distributed _FaaS-enabled edge nodes_ (or simply _edge nodes_) is deployed at the edge of the access network. 

Each of these nodes deploys a _DFaaS platform_ for the execution of _serverless functions_, and is connected to a wireless or wired _access point_ (e.g. a base station, a broadband network gateway, a WiFi access point, etc.).

The edge node can receive functions' execution _requests_, in the form of HTTP requests, generated by the _users_ served by the access point.

## Architecture

![Architecture](images/Arch-crop.png)

## Prototype
This prototype relies on [HAProxy](https://www.haproxy.org/) to implement the proxy component,
and on [faasd](https://github.com/openfaas/faasd) (a lightweight version of OpenFaaS) to implement the FaaS platform.

Also, we exploit [Sysbox](https://github.com/nestybox/sysbox), an open-source and free container runtime
(a specialized "runc") that enhances containers in two key ways:

- improves container isolation
- enables containers to run same workloads as VMs

Thanks to Sysbox we are able to run our prototype as a standalone Docker container that executes our agent,
the HAProxy and faasd all together.
This way, we can run several emulated edge nodes by simply executing multiple Docker containers.

### Requirements

#### Docker CE 20.10.14
You can follow the [official user guide](https://docs.docker.com/engine/install/).

#### Docker Compose v2
You can follow the [official user guide](https://docs.docker.com/compose/cli-command/).

#### Sysbox CE 0.5.0

You can follow the [official user guide](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md).

> We do not recommend to set up `sysbox-runc` as your default container, you can skip that part of the guide.
> 
> We instead recommend installing [shiftfs](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md#installing-shiftfs)
> according to your kernel version as suggested by the Sysbox CE user guide.

### Build Docker images

```shell
# Paths assume you are executing from the project root directory
docker build -t dfaas-agent-builder:latest -f docker/dfaas-agent-builder.dockerfile dfaasagent
docker build -t dfaas-node:latest -f docker/dfaas-node.dockerfile docker
```

### Run a 3 nodes network via Docker Compose
See the provided [docker-compose.yml](docker-compose.yml) file for technical details.
```shell
docker compose up -d
```

### Deploy functions
This script deploy the same set of functions on each of the nodes by using [docker/files/faasd/deploy_functions.sh](docker/files/faasd/deploy_functions.sh).
The [deploy_functions.sh](docker/files/faasd/deploy_functions.sh) script waits for the OpenFaaS gateway to be up (max 20 retries, 10s delay),
then deploys 4 functions (ocr, sentimentanalysis, shasum, figlet) from the OpenFaas store.

```shell
# 1st arg: number of nodes
# 2nd arg: node name prefix (e.g. dfaas-node-)
# 3rd arg: node name suffix (e.g. -1)

# Result: dfaas-node-1-1 (the default name you get when using the provided docker-compose.yml file)
./utils/deploy-functions-to-nodes.sh 3 "dfaas-node-" "-1"
```

### Invoke a function
Each node exposes port `808x` (e.g., node-1 exposed port is 8081) that maps to the proxy port `80`,
assuming you run 3 nodes via Docker Compose with the provided [docker-compose.yml](docker-compose.yml) file.

You can invoke a function (i.e. on the first node) by simply contact the proxy on `http://localhost:8081/function/{function_name}`.
```shell
curl http://localhost:8081/function/figlet -d 'Hello DFaaS world!'
```

### Execute workload to a node using [vegeta](https://github.com/tsenart/vegeta)
We provide some example that use [vegeta](https://github.com/tsenart/vegeta) HTTP load testing tool to run workload on a node.

You can install vegeta executing the following commands:
```shell
wget https://github.com/tsenart/vegeta/releases/download/v12.8.4/vegeta_12.8.4_linux_amd64.tar.gz
tar -xf vegeta_12.8.4_linux_amd64.tar.gz && rm vegeta_12.8.4_linux_amd64.tar.gz
sudo mv vegeta /usr/local/bin/
```

This example uses the vegeta [json format](https://github.com/tsenart/vegeta#json-format) and requires [jq](https://stedolan.github.io/jq/).
It runs a vegeta attack (duration: 5 minutes, rate: 50 req/s) to the `figlet` function on the first node saving results and producing report ever 200ms.

```shell
# Create the vegeta results directory
mkdir -p vegeta-results
export VEGFOLDER="vegeta-results/$(date +%Y-%m-%d-%H%M%S)"
mkdir -p $VEGFOLDER

# Run a vegeta attack (duration: 5 minutes, rate: 50 req/s) to the figlet function on the first node saving results and producing report.
jq -ncM '{method: "GET", url: "http://localhost:8081/function/figlet", body: "Hello DFaaS world!" | @base64, header: {"Content-Type": ["text/plain"]}}' | \
  vegeta attack -duration=5m -rate=50 -format=json | \
  tee $VEGFOLDER/results.bin | \
  vegeta report -every=200ms
```

### Create plots from vegeta results

```shell
# Encode results as JSON
cat $VEGFOLDER/results.bin | vegeta encode > $VEGFOLDER/results.json

# Create plot with vegeta
cat cat $VEGFOLDER/results.bin | vegeta plot > $VEGFOLDER/plot.html

# Create plot with our plot utility script (install required Python packages listed in utils/plot-requirements.txt)
# 1st arg: path int results.json
# 2nd arg: path output plot
# 3rd arg: rate req/s used for the attack
./utils/plot.py $VEGFOLDER/results.json $VEGFOLDER/plot.png 50
```

### Forwarding traffic as a malicious node
You can impersonate a malicious node that is not part of the federation by adding the header `Dfaas-Node-Id`
with a value that is not a valid peer id of the network (e.g., `Dfaas-Node-Id: malicious-id`).
All of its requests will be rejected.

### Troubleshooting

```shell
# Substitute the CONTAINER_NAME value with the desired container name
export CONTAINER_NAME="dfaas-node-1-1"
docker exec -it ${CONTAINER_NAME} bash
journalctl --follow --unit dfaasagent # ...or whatever you prefer to inspect (e.g., haproxy, faasd, faasd-provider)
```

## Emulator
For a complex setup running several emulated edge nodes with different topologies see [emulator directory](emulator).
We provide instructions and examples to execute DFaaS nodes via [Containernet emulator](https://containernet.github.io/).

## Simulator
We also provide a simulator to test and compare different load balancing techniques.
The simulation code is available into the [simulation directory](simulation).
Data gathered by the DFaaS system used for simulation are available [here](simulation/data).

For more information read associated [README](simulation/README.md) file.
