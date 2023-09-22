# lima-docker
lima-docker script for Apple Silicon Macs

Sets up up a remote docker VM that works with M1/M2 macs.  

Example lima config file uses.
1) ubuntu base image - no cgroups v2 issues like colima (Alpine) has
2) vcpus:4
3) mem:12GB
4) Disk:120GB
5) vmType: vz
6) mountType: virtiofs
7) additional mount points for gardener (i.e. BackupBucket)

Tailor to your specific needs!


lima-docker.sh

1) Configure the the Docker Context name. CONTEXT
2) Configure lima config yaml file location
3) Configure lima home directory.  Normally $HOME/.lima

The name of the lima config yaml file should match the name of the context.
(Example)
CONTEXT="test"
LIMACFG="$Home/test.yaml"

OPERATIONS:

1) test    - will run docker hello-world
2) log     - will display the latest log from the script
3) prereq  - will check and install brew pre-reqs for the script
4) start   - will start the docker vm and switch the docker context to that vm
5) stop    - will stop the docker vm and switch the docker context to 'default'
6) delete  - will delete the docker vm and switch the docker context to 'default'
7) help    - will display help

   
