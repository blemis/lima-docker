#!/usr/bin/env bash

# PreReqs
PREREQS=( lima socket_vmnet )

# name docker VM context
CONTEXT="lima-docker-rootful"

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
ACTIONS=( test log prereq status start stop delete help )

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
    printf "\n${MAG}✅ Not Running ${CYAN}as ${RED}Admin.\n"
    printf "\n${CYAN}Please ${MAG}use ${GREEN}Privileges ${CYAN}to become an administrator and ${MAG}Re-Run ${CYAN}the script.\n"
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
  printf "${CYAN}stop    - will stop the docker vm and switch the docker context to 'default'\n"
  printf "${CYAN}delete  - will delete the docker vm and switch the docker context to 'default'\n"
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
    printf "⏳ ${MAG}Checking ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
    case $STATUS in
      Running)
        COLOR=${GREEN}
        printf "${CYAN}✅ Docker VM ${YELLOW}$CONTEXT ${COLOR}$STATUS\n"
        printf "${CYAN}✅ Docker ${GREEN}Active\n"
        ;;
      Stopped)
        COLOR=${RED}
        printf "${CYAN}✅ Docker VM ${YELLOW}$CONTEXT ${COLOR}$STATUS\n"
        printf "${CYAN}✅ Docker ${RED}InActive\n"
        ;;
      *)
        COLOR=${RED}
        printf "${CYAN}✅ Docker VM ${YELLOW}$CONTEXT ${COLOR}Not Found\n"
        printf "${CYAN}✅ Docker ${RED}InActive\n"
        ;;
    esac
}

# creates/starts new or existing docker image
function start() {
    case $STATUS in
        Stopped)
            printf "\n⏳ ${MAG}Starting ${RED}Stopped ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
            limactl start --tty=false $CONTEXT > $LIMADIR/log 2>&1;;
        "")
            printf "\n⏳ ${MAG}Creating ${CYAN}and ${MAG}starting ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n" 
            limactl start --tty=false --name=$CONTEXT $LIMACFG > $LIMADIR/log 2>&1;;
        *)
            return
    esac    
    docker context rm $CONTEXT > /dev/null 2>&1
    docker context create $CONTEXT --docker "host=unix://$LIMADIR/$CONTEXT/sock/docker.sock" > /dev/null 2>&1
    docker context use $CONTEXT > /dev/null 2>&1
    status
    printf "${CYAN}✅ Docker Context ${GREEN}Changed ${CYAN}to ${YELLOW}$CONTEXT\n"
    printf "⏳ ${MAG}Running ${GREEN}Test.${NO_COLOR}\n\n"
    docker_test
}

# stops current context docker image
function stop() { 
    if [ "$STATUS" = "Running" ]; then
        printf "⏳ ${MAG}Stopping ${CYAN}Docker VM ${YELLOW}$CONTEXT.\n"
        limactl stop $CONTEXT > $LIMADIR/log 2>&1
        printf "${CYAN}✅ Docker ${RED}InActive\n"
    fi
    docker context use default > /dev/null 2>&1
    printf "⏳ ${MAG}Switching ${CYAN}Docker Context to ${YELLOW}default.\n"
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
      printf "${CYAN}✅ Docker ${RED}InActive\n"
      docker context use default > /dev/null 2>&1
      printf "⏳ ${MAG}Switching ${CYAN}Docker Context to ${YELLOW}default.\n"
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
   *)
     status
esac
printf "\n\n${BLUE}***********************************************\n"