#!/bin/sh
set -e

# volume mounts
export CONF_MOUNT_PATH=${WORKING_DIRECTORY}/wso2-config-volume
export SECRET_MOUNT_PATH=${WORKING_DIRECTORY}/wso2-secret-volume

deployment_volume=${WSO2_SERVER_HOME}/repository/deployment/server
# original deployment artifacts
original_deployment_artifacts=${WORKING_DIRECTORY}/wso2-tmp/server

# a grace period for mounts to be setup
echo "Waiting for all volumes to be mounted..."
sleep 2

verification_count=0
verifyMountBeforeStart()
{
  if [ ${verification_count} -eq 10 ]
  then
    echo "Mount verification timed out"
    return
  fi

  # increment the number of times the verification had occurred
  verification_count=$((verification_count+1))

  if [ ! -e $1 ]
  then
    echo "Directory $1 does not exist"
    echo "Waiting for the volume to be mounted..."
    sleep 1

    echo "Retrying..."
    verifyMountBeforeStart $1
  else
    echo "Directory $1 exists"
  fi
}

verifyMountBeforeStart ${CONF_MOUNT_PATH}
verification_count=0
verifyMountBeforeStart ${SECRET_MOUNT_PATH}


# capture Docker container IP from the container's /etc/hosts file
docker_container_ip=$(awk 'END{print $1}' /etc/hosts)

# check if the WSO2 non-root user home exists
test ! -d ${WORKING_DIRECTORY} && echo "WSO2 Docker non-root user home does not exist" && exit 1

# check if the WSO2 product home exists
test ! -d ${WSO2_SERVER_HOME} && echo "WSO2 Docker product home does not exist" && exit 1

# copy any configuration changes mounted to config volumes
sh ${WSO2_SERVER_HOME}/bin/copyConfigs.sh
# make any node specific configuration changes
# for example, set the Docker container IP as the `localMemberHost` under axis2.xml clustering configurations (effective only when clustering is enabled)
sed -i "s#<parameter\ name=\"localMemberHost\".*<\/parameter>#<parameter\ name=\"localMemberHost\">${docker_container_ip}<\/parameter>#" ${WSO2_SERVER_HOME}/repository/conf/axis2/axis2.xml

# start WSO2 Carbon server
sh ${WSO2_SERVER_HOME}/bin/wso2server.sh
