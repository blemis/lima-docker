# lima-docker
lima-docker script for Apple Silicon Macs

Sets up up a remote docker VM that works with M1/M2 macs.  
Uses new Apple virtualization type "vz" and experimental mount type "virtiofs".
Replaces Docker Desktop, and removes some limitations of colima.

## lima-docker-rootful.yaml
Example lima-docker-rootful.yaml config file uses.
1) ubuntu base image - no cgroups v2 issues like colima (Alpine) has
2) vcpus:4
3) mem:12GB
4) Disk:120GB
5) vmType: vz
6) mountType: virtiofs
7) additional mount points for gardener (i.e. BackupBucket)

Tailor to your specific needs!


## lima-docker.sh

1) Configure the the Docker Context name. $CONTEXT (i.e. "lima-docker-rootful")
2) Confiugure the Docker Default context $DEFAULT  (i.e. "default")
3) Configure lima config yaml file location.  (i.e. $HOME/artifacts/lima)
4) Configure lima home directory. (i.e. $HOME/.lima)

The name of the lima config yaml file should match the name of the context.

(Example)

CONTEXT="lima-docker-rootful"

LIMACFG="$Home/artifacts/lima/lima-docker-rootful.yaml"

## Command Line ARGS:  

lima-docker.sh ARG

1) test    - will run docker hello-world
2) log     - will display the latest log from the script
3) prereq  - will check and install brew pre-reqs for the script
4) status  - will show the current status of the Docker VM and Docker Context
5) start   - will start the docker vm and switch the docker context to $CONTEXT
6) stop    - will stop the docker vm and switch the docker context to $DEFAULT
7) delete  - will delete the docker vm and switch the docker context to $DEFAULT
8) fix     - will switch the Docker Context to $CONTEXT
9) version - will display the version info
10) shell  - will launch bash shell in DOCKER VM $CONTEXT
11) config - will use $EDITOR to edit the lima config file $LIMACFG
12) help   - will display help
## Aliases

add to your .bashrc, .bash_aliases, or .zshrc file