echo "#########################################################"
echo "##  include-raw-integration-configuration_functions.sh ##"
echo "#########################################################"

# writes the  functions needed for configuring clustering to 
# configuration-functions.sh  in the  WORKSPACE
env

set -x

cat > ${WORKSPACE}/configuration-functions.sh  <<EOF

# Receives argument to GREP slaves address_txt e.g. 'CONTROLLER'. 
# Expects slave_addresses.txt is available

function getslaveaddresses 
{
   declare -a CONTROLLERIPS=($CONTROLLER0, $CONTROLLER1, $CONTROLLER2)
   declare -p CONTROLLERIPS
   export CONTROLLERIPS
}


function editakkaconf  
{
set -x
# Expects 1 argument \$LOOPINCR. 
# \$CONTROLLERIPS[] is set by getslaveaddresses(). 
# \$BUNDLEFOLDER is set in "include-raw-integration-deploy-controller.sh" 
# A single copy of akka.conf is assumed to be available in \$BUNDLEFOLDER

if [ -z ${BUNDLEFOLDER} ] || [ -f ${BUNDLEFOLDER} ]; then
    echo "WARNING: Location of ODL BUNDLEFOLDER:\$BUNDLEFOLDER is not defined"

fi
if [ -z \${CONTROLLERIPS} ]; then
    echo "WARNING: Cluster IPs not known due to UNBOUND varible: CONTROLLERIPS[@] does not exist"
    echo "WARNING: Calling getslaveaddresses to populate  CONTROLLERIPS[@]"
    getslaveaddresses
fi




############################ 
# BEGIN function variables #
############################

  # make local copies of global varibles because globals may produce interesting bugs.

  local LOOPINCR=\$1
  local AKKACONF=\$(find /tmp/${BUNDLEFOLDER} -name akka.conf)
  # set the IP of the current controller. Uses  \$CONTROLLERIPS[] and \$LOOPINCR

  local CURRENTCONTROLLERIPADDR=( "\${CONTROLLERIPS[\$1]}" )
  declare -p CURRENTCONTROLLERIPADDR 
  
  # used to verify IP address of current VM
  local HOSTIPADDR=\$(/sbin/ifconfig eth0 | grep "inet " | awk '{print \$2}' | awk '{print \$1}')

  local CLUSTERDATAORIG="\"akka.tcp:\/\/opendaylight-cluster-data@127.0.0.1:2550"\"
  local CLUSTERDATANEW="\"akka.tcp:\/\/opendaylight-cluster-data@$CONTROLLER0:2550\",\"akka.tcp:\/\/opendaylight-cluster-data@$CONTROLLER1:2550\",\"akka.tcp:\/\/opendaylight-cluster-data@$CONTROLLER2:2550"\"

  local CLUSTERRPCORIG="\"akka.tcp:\/\/odl-cluster-rpc@127.0.0.1:2551"\"
  local CLUSTERRPCNEW="\"akka.tcp:\/\/odl-cluster-rpc@$CONTROLLER0:2551\",\"akka.tcp:\/\/odl-cluster-rpc@$CONTROLLER1:2551\",\"akka.tcp:\/\/odl-cluster-rpc@$CONTROLLER2:2551\""

  local UIDORIG="member-1"
  local UIDNEW="member-\$1"

########################## 
# END function variables #
##########################

#####################################
# sanity test hostname in akka.conf #
#####################################
# probably overkill as SCP depends on IPaddress being correct.

#set -x
  if [ -z \${HOSTIPADDR} ]; then 
    echo "WARNING:  HOSTIPADDR is empty."
  fi

#set +x

  if [ "${CURRENTCONTROLLERIPADDR}" == "${HOSTIPADDR}" ] 
  then 
    echo "CURRENTCONTROLLERIPADRR:${CURRENTCONTROLLERIPADDR} == HOSTIPADDR:${HOSTIPADDR}"
  else
    echo "WARNING: CURRENTCONTROLLERIPADRR:${CURRENTCONTROLLERIPADDR} != HOSTIPADDR:${HOSTIPADDR}"
  fi

####################################
# configure  hostname in akka.conf #
####################################
  
  cp \${AKKACONF} \${AKKACONF}.bak
  sed -ri "s:hostname = \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\":hostname =
\$CURRENTCONTROLLERIPADDR:" \${AKKACONF}.bak

####################################
# configure  seednode in akka.conf #
####################################

  sed -i "s/\$CLUSTERDATAORIG/\$CLUSTERDATANEW/g" \${AKKACONF}.bak
  sed -i "s/\$CLUSTERRPCORIG/\$CLUSTERRPCNEW/g" \${AKKACONF}.bak

####################################
# define unique name for each node #
####################################

  sed -i "s/\$UIDORIG/\$UIDNEW/g" \${AKKACONF}.bak
  cp \${AKKACONF}.bak \${AKKACONF}
  cat \${AKKACONF}
set +x  
}
function configuremoduleshardsconf
{
  set -x
  if [ -z ${BUNDLEFOLDER} ] || [ -f ${BUNDLEFOLDER} ]; then
    echo "MODULESHARDSCONF WARNING:  Location of ODL BUNDLEFOLDER:\$BUNDLEFOLDER is not defined"
  fi

  local REPLICACONFORIG='"member-1"'
  local REPLICACONFNEW='"member-0",\n\t\t\t"member-1",\n\t\t\t"member-2"'
  

  MODULESHARDSCONF=\$(find /tmp/${BUNDLEFOLDER} -name module-shards.conf)

  if [ -z \${MODULESHARDSCONF} ] 
  then
    printf "source file module-shards.conf  was not found\n"
  else
    printf "MODULESHARDSCONF: \${MODULESHARDSCONF}"
    cp \${MODULESHARDSCONF} \${MODULESHARDSCONF}.bak 
    printf \$REPLICACONFNEW
    sed -i "s/\$REPLICACONFORIG/\$REPLICACONFNEW/g" \${MODULESHARDSCONF}.bak 

    cp \${MODULESHARDSCONF}.bak  \${MODULESHARDSCONF} 
    cat \${MODULESHARDSCONF}
 fi  
 set +x
}

function deployandruncontrollerscript
{
  local CONTROLLERIP=\$1
  echo "running controller \$CONTROLLERIP" 
  scp \${WORKSPACE}/controller-script.sh \$CONTROLLERIP:/tmp
  ssh \$CONTROLLERIP 'bash /tmp/controller-script.sh'
}


function deploycontrollerscript
{
  local CONTROLLERIP=\$1
  local SCRIPT=\$2
  echo "deploy controller \$CONTROLLERIP on \$i" 
  scp -v \${WORKSPACE}/\$SCRIPT  \$CONTROLLERIP:/tmp
}


function runcontrollerscript
{
  local CONTROLLERIP=\$1
  local SCRIPT=\$2
  echo "run controller \$CONTROLLERIP on \$i" 
  ssh -v \$CONTROLLERIP 'bash /tmp/\$SCRIPT'
}

EOF
set +x


#less configuration-functions.sh
echo "############################################################"
echo "## END include-raw-integration-configuration_functions.sh ##"
echo "############################################################"

