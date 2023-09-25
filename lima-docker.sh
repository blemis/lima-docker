#!/usr/bin/env bash
#
# Copyright 2023 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Using Gardener?
GARDENER=true

# PreReqs
PREREQS=( lima socket_vmnet docker jq )

# name docker VM context
CONTEXT="lima-docker-rootful"
DEFAULT="default"

# lima config locations
LIMACFG="$HOME/artifacts/lima/$CONTEXT.yaml"
LIMADIR="$HOME/.lima"

# color setup
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
GREENBACK='\033[0;42m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAG='\033[0;35m'
NO_COLOR='\033[0m'

# Actions
ACTIONS=( test log prereq status start stop delete fix help )

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
check_priv() {
  if ! (groups $USER | grep -q -w admin); then
    printf "\n${MAG}❌ Not Running ${CYAN}as ${RED}Admin.\n"
    printf "\n${CYAN}✅ Please ${MAG}use ${GREEN}Privileges ${CYAN}to become an administrator and ${MAG}Re-Run ${CYAN}the script.\n"
    printf "\n\n${BLUE}***********************************************\n"
    exit 1
  else
    printf "\n${MAG}✅ Running ${CYAN}as ${GREEN}Admin.\n"
  fi
}

# Show log
show_log() {
  cat $LIMADIR/log
}

# Show help
show_help() {
  printf "${CYAN}test    - will run docker hello-world\n"
  printf "${CYAN}log     - will display the latest log from the script\n"
  printf "${CYAN}prereq  - will check and install brew pre-reqs for the script\n"
  printf "${CYAN}start   - will start the docker vm and switch the docker context to that vm\n"
  printf "${CYAN}stop    - will stop the docker vm and switch the docker context to $DEFAULT\n"
  printf "${CYAN}delete  - will delete the docker vm and switch the docker context to $DEFAULT\n"
  printf "${CYAN}fix  - will switch the docker context to $CONTEXT\n"
  printf "${CYAN}help    - show this\n"
}

# Check brew formulas
formula_installed() {
    [ "$(brew list | grep $1)" ]
    return $?
}

# Check PreReqs and install if needed
process_prereq() {
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

# cheap way to get status from lima
function status() {
    STATUS=`(limactl list --log-level error --json |jq -r  --arg CONTEXT "$CONTEXT" 'select( .name as $a | $CONTEXT | index($a))'| jq .status)|tr -d '"'`
    get_context
    printf "⏳ ${MAG}Checking ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
    case $STATUS in
      Running)
        COLOR=${GREEN}
        printf "${CYAN}✅ Docker VM ${YELLOW}$CONTEXT ${COLOR}$STATUS\n"
        if [[ "$CURR_CONTEXT" != "$CONTEXT" ]]; then
          printf "${CYAN}❌ Docker ${GREEN}Active${CYAN}, but set to context ${RED}$CURR_CONTEXT.\n"
        else
          printf "${CYAN}✅ Docker ${GREEN}Active\n"
        fi
        ;;
      Stopped)
        COLOR=${RED}
        printf "${CYAN}❌ Docker VM ${YELLOW}$CONTEXT ${COLOR}$STATUS\n"
        printf "${CYAN}❌ Docker ${RED}InActive\n"
        ;;
      *)
        COLOR=${RED}
        printf "${CYAN}❌ Docker VM ${YELLOW}$CONTEXT ${COLOR}Not Found\n"
        printf "${CYAN}❌ Docker ${RED}InActive\n"
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
    printf "\n${CYAN}✅Current Docker Context ${YELLOW}$CURR_CONTEXT ${CYAN}and Docker VM ${YELLOW}$CONTEXT ${CYAN}already ${GREEN}match.\n" 
  fi
}

# creates/starts new or existing docker image
function start() {
    case $STATUS in
        Stopped)
            printf "\n⏳ ${MAG}Starting ${RED}Stopped ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
            limactl start --tty=false $CONTEXT > /dev/null 2>&1;;
        "")
            printf "\n⏳ ${MAG}Creating ${CYAN}and ${MAG}starting ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n" 
            limactl start --tty=false --name=$CONTEXT $LIMACFG > /dev/null 2>&1;;
        *)
            return
    esac    
    fix_context
    # Gardener specific dirs that need to be readable 
    if ( $GARDENER ); then
      printf "⏳ ${MAG}Adding ${CYAN}GARDENER Specific Config.\n" 
      limactl shell $CONTEXT sudo mkdir -m 0777 -p \
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
        printf "⏳ ${MAG}Stopping ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
        limactl stop $CONTEXT > $LIMADIR/log 2>&1
        printf "${CYAN}❌ Docker ${RED}InActive\n"
    fi
    docker context use $DEFAULT > /dev/null 2>&1
    CURR_CONTEXT=$DEFAULT
    printf "⏳ ${MAG}Switching ${CYAN}Docker Context to ${YELLOW}$DEFAULT.\n"
}

# deletes current context docker image
function delete() {
    if [ "$STATUS" = "Running" ]; then
        printf "⏳ ${MAG}Stopping ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
        limactl stop $CONTEXT > $LIMADIR/log 2>&1
        
    fi
    limactl rm $CONTEXT > /dev/null 2>&1
    if ! [ "$STATUS" = "" ]; then
      printf "\n⏳ ${MAG}Deleting ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
      printf "${CYAN}✅ Docker VM ${YELLOW}$CONTEXT ${RED}Deleted\n"
      printf "${CYAN}❌ Docker ${RED}InActive\n"
      docker context use $DEFAULT > /dev/null 2>&1
      printf "⏳ ${MAG}Switching ${CYAN}Docker Context to ${YELLOW}$DEFAULT.\n"
      CURR_CONTEXT=$DEFAULT
    else
      printf "${CYAN}✅ Nothing to delete.\n"
    fi    
}

# Runs hello-world as a test
function docker_test() {
  if [ "$STATUS" = "Running" ]; then
    docker run hello-world
  else 
    printf "⏳${CYAN} Test ${MAG}skipped. ${CYAN}Please ${MAG}start ${CYAN}docker.\n"
  fi
}

printf "\n\n${BLUE}***********************************************\n"
check_priv
case $OP in
   help)
     show_help;;
   log)
     show_log;;
   prereq)
     process_prereq;;
   start)
     status
     start;;
   stop)
     status
     stop;;
   delete)
     status
     delete;;
   test)
     status
     docker_test;;
   fix)
    fix_context;;
   *)
     status;;
esac
printf "\n\n${BLUE}***********************************************\n"
