#!/usr/bin/env bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} ARGS ...
#%
#% DESCRIPTION
#%    This script manages and creates a rootful docker vm using
#%    lima.
#%
#% ARGS
#%    test    - will run docker hello-world
#%    log     - will display the latest log from the script
#%    prereq  - will check and install brew pre-reqs for the script
#%    status  - will show the current status of the Docker VM and Docker Context
#%    start   - will start the docker vm and switch the docker context to $CONTEXT
#%    stop    - will stop the docker vm and switch the docker context to $DEFAULT
#%    delete  - will delete the docker vm and switch the docker context to $DEFAULT
#%    fix     - will switch the Docker Context to $CONTEXT
#%    version - will display the version info
#%    shell  - will launch bash shell in DOCKER VM $CONTEXT
#%    config - will use $EDITOR to edit the lima config file $LIMACFG
#%    help   - will display help
#%
#% EXAMPLES
#%    ${SCRIPT_NAME} start 
#%    ${SCRIPT_NAME} stop
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} (www.sap.com) 1.0.0
#-    author          Jeff Estes
#-    copyright       Copyright (c) 2023 SAP SE or an SAP affiliate company. All rights reserved.
#-    license         GNU General Public License 3.0
#-
#================================================================
#  HISTORY
#     2023/09/25 : jeff.estes01@sap.com : Script creation
# 
#================================================================
# END_OF_HEADER
#================================================================

# Script Name
SCRIPT_NAME="${0##*/}"

# Version
VERSION=1.0.3

# color setup
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
GREENBACK='\033[0;42m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAG='\033[0;35m'
BLINK='\033[31;5m'
NO_COLOR='\033[0m'

# Set Editor
if ! [ $EDITOR ]; then
  EDITOR="/usr/bin/vim"
fi

# PreReqs
PREREQS=( lima socket_vmnet docker jq )

# Using Gardener?
GARDENER=true

# name docker VM context
CONTEXT="lima-docker-rootful"
CURR_CONTEXT=`(docker context inspect|jq -r '.[]| .Name')`
DEFAULT="default"

# lima config locations
LIMACFG="$HOME/artifacts/lima/$CONTEXT.yaml"
LIMADIR="$HOME/.lima"

# Actions
ACTIONS=( test log prereq status start stop delete fix help shell config version )

# Status
STATUS=""

# Check Line Args (should be 1)
if [ "$#" -lt 1 ]; then
  printf "${CYAN}Usage: ${GREEN}$0 ${RED}<"
  for action in ${ACTIONS[*]}
    do
      printf "${YELLOW}$action${RED}//"
    done
  printf "${RED}>\n"
  exit 1
fi

OP=$1

#Check privileges -make sure everyone is running with admin
function check_priv() {
  if ! (groups $USER | grep -q -w admin); then
    printf "\n${MAG}❌ Not Running ${CYAN}as ${RED}Admin.\n\n"
    printf "\n${CYAN}✅ Please ${MAG}use ${GREEN}Privileges ${CYAN}to become an administrator and ${MAG}Re-Run ${CYAN}the script.\n"
    printf "\n\n${BLUE}***********************************************\n"
    exit 1
  #else
  #  printf "\n${MAG}✅ Running ${CYAN}as ${GREEN}Admin.\n\n"
  fi
}

# Show log
function show_log() {
  cat $LIMADIR/log
}

# Show help
function show_help() {
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}test    - ${GREEN}will run Docker hello-world\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}log     - ${GREEN}will display the latest log from the script\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}prereq  - ${GREEN}will check and install brew pre-reqs for the script\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}status  - ${GREEN}will show the current status of the Docker VM and Docker Context\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}start   - ${GREEN}will start the Docker VM and switch the Docker Context to that VM\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}stop    - ${GREEN}will stop the Docker VM and switch the Docker Context to ${CYAN}\$DEFAULT\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}delete  - ${GREEN}will delete the Docker VM and switch the Docker Context to ${CYAN}\$DEFAULT\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}fix     - ${GREEN}will switch the Docker Context to ${CYAN}\$CONTEXT\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}version - ${GREEN}will display the version info\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}shell   - ${GREEN}will shell into Docker VM ${CYAN}\$CONTEXT\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}config  - ${GREEN}will use $EDITOR to edit the lima config file ${CYAN}\$LIMACFG\n"
  printf "${MAG}${SCRIPT_NAME} ${YELLOW}help    - ${GREEN}show this\n"
}

# Get shell for Docker VM
function get_shell() {
  if [ "$STATUS" = "Running" ] &&  [ "$CURR_CONTEXT" = "$CONTEXT" ]; then
    printf "\n${MAG}Bashing ${CYAN}into Docker VM.\n\n"
    limactl shell --log-level info $CONTEXT bash
    printf "\n${MAG}Exiting ${CYAN}Docker VM ${YELLOW}$CONTEXT\n\n"
  else
    printf "${CYAN}❌ Docker VM ${YELLOW}$CONTEXT ${RED}Not Found${NO_COLOR}\n"
    printf "${CYAN}❌ Docker ${RED}InActive${NO_COLOR}\n" 
  fi
}

# Edit the Lima Config file
function edit_config() {
  $EDITOR $LIMACFG
  printf "${MAG}Exiting ${CYAN}config file ${YELLOW}$LIMACFG\n"
}

# Check command line args
function check_op() {
  if [[ ${ACTIONS[@]} =~ $OP ]]; then
    printf "\n${GREEN}Running $OP\n"
  else
    printf "\n${CYAN}Command ${RED}$OP ${CYAN}not found.\n\n"
    exit 0
  fi 
  printf "${BLUE}***********************************************\n"
}

# Check brew formulas
function formula_installed() {
    [ "$(brew list | grep $1)" ]
    return $?
}

# Check PreReqs and install if needed
function process_prereq() {
    printf "${CYAN}Checking/Installing pre-reqs you may need to provide a password for sudo.\n"
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

function silent_status() {
  STATUS=`(limactl list --log-level error --json |jq -r  --arg CONTEXT "$CONTEXT" 'select( .name as $a | $CONTEXT | index($a))'| jq .status)|tr -d '"'`
}

# cheap way to get status from lima
function status() {
    silent_status
    get_context
    printf "⏳ ${MAG}Checking ${CYAN}Docker VM.\n"
    case $STATUS in
      Running)
        COLOR=${GREEN}
        printf "${CYAN}✅ Docker VM ${COLOR}$STATUS\n"
        if [[ "$CURR_CONTEXT" != "$CONTEXT" ]]; then
          printf "${CYAN}❌ Docker ${GREEN}Active${CYAN}, but set to different context ${RED}$CURR_CONTEXT.\n"
        else
          printf "${CYAN}✅ Docker ${GREEN}Active\n"
        fi
        ;;
      Stopped)
        COLOR=${RED}
        printf "${CYAN}❌ Docker VM ${COLOR}$STATUS\n"
        printf "${CYAN}❌ Docker ${RED}InActive\n"
        ;;
      *)
        printf "${CYAN}❌ Docker VM ${RED}Not Found${NO_COLOR}\n"
        printf "${CYAN}❌ Docker ${RED}InActive${NO_COLOR}\n"
        ;;
    esac
}

# get current docker context
function get_context() {
  CURR_CONTEXT=`(docker context inspect|jq -r '.[]| .Name')`
  if [[ "$CURR_CONTEXT" != "$CONTEXT" ]]; then
    printf "${CYAN}❌ Current Docker Context ${RED}$CURR_CONTEXT.\n"
  else
    printf "${CYAN}✅ Current Docker Context ${YELLOW}$CURR_CONTEXT.\n"
  fi
}

# fix docker context
function fix_context() {
  CURR_CONTEXT=`(docker context inspect|jq -r '.[]| .Name')`
  if [[ "$CURR_CONTEXT" != "$CONTEXT" ]]; then
    printf "\n⏳ ${MAG}Changing ${CYAN}Docker Context from ${RED}$CURR_CONTEXT ${CYAN}to ${YELLOW}$CONTEXT.\n" 
    docker context rm $CONTEXT > /dev/null 2>&1
    docker context create $CONTEXT --docker "host=unix://$LIMADIR/$CONTEXT/sock/docker.sock" > /dev/null 2>&1
    docker context use $CONTEXT > /dev/null 2>&1
    CURR_CONTEXT=$CONTEXT
  else
    printf "\n${CYAN}✅ Current Docker Context ${YELLOW}$CURR_CONTEXT ${CYAN}and Docker VM ${CYAN}already ${GREEN}match.\n" 
  fi
}

# creates/starts new or existing docker image
function start() {
    case $STATUS in
        Stopped)
            printf "\n⏳ ${MAG}Starting ${RED}Stopped ${CYAN}Docker VM.\n"
            limactl start --log-level info --tty=false $CONTEXT > $LIMADIR/log 2>&1;;
        "")
            printf "\n⏳ ${MAG}Creating ${CYAN}and ${MAG}starting ${CYAN}Docker VM.\n" 
            limactl start --log-level info --tty=false --name=$CONTEXT $LIMACFG > $LIMADIR/log 2>&1;;
        *)
            return
    esac    
    fix_context
    # Gardener specific dirs that need to be readable 
    if ( $GARDENER ); then
      printf "⏳ ${MAG}Adding ${CYAN}GARDENER Specific Config.\n" 
      limactl shell $CONTEXT sudo mkdir -m 0777 -p \
        /etc/gardner \
        /etc/gardener/local-registry \
        /etc/gardener/local-registry/gcr \
	      /etc/gardener/local-registry/localhost \
	      /etc/gardener/local-registry/gcr-eu \
	      /etc/gardener/local-registry/ghcr \
	      /etc/gardener/local-registry/k8s \
	      /etc/gardener/local-registry/quay
    fi
    status
    printf "⏳ ${MAG}Running ${GREEN}Test.${NO_COLOR}\n\n"
    docker_test
}

# stops current context docker image
function stop() { 
    if [ "$STATUS" = "Running" ]; then
        printf "⏳ ${MAG}Stopping ${CYAN}Docker VM.\n"
        limactl stop --log-level info $CONTEXT > $LIMADIR/log 2>&1
        printf "${CYAN}✅ Docker ${RED}InActive${NO_COLOR}\n"
    else
       printf "${CYAN}✅ Docker already ${RED}InActive${NO_COLOR}\n"
    fi
    docker context use $DEFAULT > /dev/null 2>&1
    CURR_CONTEXT=$DEFAULT
    printf "⏳ ${CYAN}Docker Context is now ${YELLOW}$DEFAULT.\n"
}

# deletes current context docker image
function delete() {
    if [ "$STATUS" = "Running" ]; then
        printf "⏳ ${MAG}Stopping ${CYAN}Docker VM.\n"
        limactl stop --log-level info $CONTEXT > $LIMADIR/log 2>&1
        
    fi
    limactl rm --log-level info $CONTEXT > $LIMADIR/log 2>&1
    if ! [ "$STATUS" = "" ]; then
      printf "\n⏳ ${MAG}Deleting ${CYAN}Docker VM.\n"
      printf "${CYAN}✅ Docker VM ${RED}Deleted\n"
      printf "${CYAN}✅ Docker ${RED}InActive\n"
      docker context use $DEFAULT > /dev/null 2>&1
      printf "⏳ ${MAG}Switching ${CYAN}Docker Context to ${YELLOW}$DEFAULT.\n"
      CURR_CONTEXT=$DEFAULT
    else
      printf "${CYAN}✅ Nothing to delete.\n"
    fi    
}

# Runs hello-world as a test
function docker_test() {
  if [ "$STATUS" = "Running" ] &&  [ "$CURR_CONTEXT" = "$CONTEXT" ]; then
    docker run hello-world
  else 
    printf "⏳${CYAN} Test ${MAG}skipped. ${CYAN}Please ${MAG}start/fix ${CYAN}docker.\n"
  fi
}



check_priv
check_op
case $OP in
   help)
     show_help;;
   log)
     show_log;;
   prereq)
     process_prereq;;
   start)
     silent_status
     start;;
   stop)
     silent_status
     stop;;
   delete)
     silent_status
     delete;;
   test)
     silent_status
     docker_test;;
   fix)
    fix_context;;
   version)
     printf "\nVersion: ${GREEN}$VERSION";;
   status)
     status;;
   shell)
     silent_status
     get_shell;;
   config)
     edit_config;;
   *)
    exit 
esac
printf "\n\n${BLUE}***********************************************\n"
