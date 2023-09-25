#!/usr/bin/env bash
#
# This script starts a local gardener cluster using kind on a M1/M2 mac.
# It uses a remote docker engine running in lima using the vz VM type
# File Mounting uses virtiofs, 

# The mount configuration for the docker engine must include 
# - location: "/Users/I741021/gardener/dev" or the local backupbucket will fail


# PreRequisites
# K9s is installed
# Git is installed and configured
# Kind is installed 
# Lima is installed with Remote Docker Engine
# Docker 
PREREQS=( lima socket_vmnet k9s kind docker jq iproute2mac parallel coreutils gnu-sed gnu-tar grep gzip )

SLEEP=120
SRC="$HOME/gardener"

# color setup
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
GREENBACK='\033[0;42m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAG='\033[0;35m'
NO_COLOR='\033[0m'

#Check privileges -make sure everyone is running with admin
check_priv() {
  if ! (groups $USER | grep -q -w admin); then
    printf "\n${MAG}❌ Not Running ${CYAN}as ${RED}Admin.\n"
    printf "\n${CYAN}Please ${MAG}use ${GREEN}Privileges ${CYAN}to become an administrator and ${MAG}Re-Run ${CYAN}the script.\n"
    printf "\n\n${BLUE}***********************************************\n"
    exit 1
  else
    printf "\n${MAG}✅ Running ${CYAN}as ${GREEN}Admin.\n"
  fi
}

# Check if we have docker running
check_docker_conn() {
  if ! (docker ps > /dev/null 2>&1); then
    printf "\n❌${RED} No docker!${NO_COLOR}\n"
    exit 1
  else
   printf "\n${GREEN}✅ We have docker!\n"
fi
}

# Check brew formulas
formula_installed() {
    [ "$(brew list | grep $1)" ]
    return $?
}

# Check PreReqs and install if needed
process_prereq() {
    printf "${CYAN}Checking-Installing pre-reqs you may need to provide a password for sudo.\n"
    for item in ${PREREQS[*]}
      do
        formula_installed $item
        if [ $? = 1 ]; then
          printf "\n${MEG}⏳ Installing ${CYAN}$item."
          brew install $item
        else
          printf "\n${CYAN}✅ $item ${GREEN}Installed."
        fi
      done
}

# fires off K9s so you can see the cluster build
function k9s() {
  osascript &>/dev/null <<EOF
    tell application "iTerm"
      set myterm to (create window with default profile)
      set bounds of myterm to {300, 30, 2000, 1200}
      tell current session of myterm
        write text "kind export kubeconfig --name gardener-local"
        write text "k9s"
      end tell
    end tell
EOF
}

# clones gardener repo if you dont have it
function clone() {
  cd $HOME
  printf "\n\n⏳ ${MAG}Checking ${CYAN}for Gardener Repo.\n"
  if [ ! -d "$SRC" ]; then
    printf "\n❌ ${CYAN}$SRC ${RED}does not exist.\n"
  else 
    cd $SRC
    if git rev-parse --git-dir > /dev/null 2>&1; then    
      printf "\n✅${CYAN} Repository ${GREEN}OK.${NO_COLOR}\n"
      return 0
    else 
      printf "\n❌ ${CYAN}Gardener Repo ${RED}doesnt look right.\n"
    fi
  fi
  cd $HOME
   printf "\n⏳ ${MAG}Backing up ${CYAN}old Gardener Repo to $SRC.old .\n"
  mv $SRC $SRC.old > /dev/null 2>&1
  rm -rf $SRC
  printf "\n⏳ ${MAG}Cloning ${CYAN}Gardener Repo.\n"
  if ! (git clone git@github.com:gardener/gardener.git); then
    printf "\n❌ ${RED}Clone not successful.  Check your Git config. Exiting...${NO_COLOR}\n"
    exit 0
  fi
  cd $SRC
}

# starts the kind cluster for gardener
function start-kind() {
  cd $SRC
  printf "\n\n⏳ ${MAG}Starting ${CYAN}Kind Cluster.\n\n"
  mkdir -p dev > /dev/null 2>&1
  chmod 755 dev > /dev/null 2>&1
  make kind-up
  printf "\n\n⏳ ${MAG}Exporting ${CYAN}KUBECONFIG.\n\n"
  kind export kubeconfig --name gardener-local > /dev/null 2>&1
  export KUBECONFIG=$SRC/example/gardener-local/kind/local/kubeconfig
  printf "\n\n ✅ Yippie! ✅ ...\n\n"
  k9s 
}

# starts gardener and seed 
function start-gardener() {
  printf "\n\n⏳ ${MAG}Starting ${CYAN}gardener.\n\n"
  make gardener-up
  $SRC/hack/usage/wait-for.sh seed local GardenletReady SeedSystemComponentsHealthy ExtensionsReady
}

# starts shoot cluster
function start-shoot() {
  printf "\n\n⏳ ${MAG}Starting ${CYAN}shoot cluster.\n\n"
  kubectl apply -f $SRC/example/provider-local/shoot.yaml
  printf "\n\n⏳ ${MAG}Waiting ${CYAN}for Shoot cluster to stabilize...\n\n"
  sleep $SLEEP &
  wait
  NAMESPACE=garden-local $SRC/hack/usage/wait-for.sh shoot local APIServerAvailable ControlPlaneHealthy ObservabilityComponentsHealthy EveryNodeReady SystemComponentsHealthy
}

# clean up /etc/hosts
function clean() {
  printf "\n\n⏳ ${MAG}Cleaning ${CYAN}up /etc/hosts.\n\n"
  sudo sed -i '/.local.gardener.cloud/d' /etc/hosts
  sudo sed -i '/cluster/d' /etc/hosts
  sudo sed -i '/garden/d' /etc/hosts
  sudo sed -i '/^$/d' /etc/hosts
  cat <<EOF | sudo tee -a /etc/hosts

# Manually created to access local Gardener shoot clusters.
# TODO: Remove this again when the shoot cluster access is no longer required.
127.0.0.1 api.local.local.external.local.gardener.cloud
127.0.0.1 api.local.local.internal.local.gardener.cloud

127.0.0.1 api.e2e-managedseed.garden.external.local.gardener.cloud
127.0.0.1 api.e2e-managedseed.garden.internal.local.gardener.cloud
127.0.0.1 api.e2e-hib.local.external.local.gardener.cloud
127.0.0.1 api.e2e-hib.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-hib-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-hib-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-unpriv.local.external.local.gardener.cloud
127.0.0.1 api.e2e-unpriv.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-wake-up.local.external.local.gardener.cloud
127.0.0.1 api.e2e-wake-up.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-wake-up-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-wake-up-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-migrate.local.external.local.gardener.cloud
127.0.0.1 api.e2e-migrate.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-migrate-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-migrate-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-rotate.local.external.local.gardener.cloud
127.0.0.1 api.e2e-rotate.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-rotate-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-rotate-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-default.local.external.local.gardener.cloud
127.0.0.1 api.e2e-default.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-default-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-default-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-upd-node.local.external.local.gardener.cloud
127.0.0.1 api.e2e-upd-node.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-upd-node-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-upd-node-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-upgrade.local.external.local.gardener.cloud
127.0.0.1 api.e2e-upgrade.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-upgrade-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-upgrade-wl.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-upg-hib.local.external.local.gardener.cloud
127.0.0.1 api.e2e-upg-hib.local.internal.local.gardener.cloud
127.0.0.1 api.e2e-upg-hib-wl.local.external.local.gardener.cloud
127.0.0.1 api.e2e-upg-hib-wl.local.internal.local.gardener.cloud
EOF
}

function main() {
  check_priv
  process_prereq
  clone
  start-kind
  start-gardener
  start-shoot
  clean
  cd ${HOME}
  printf "✅ Start Up Complete..."
}

main
