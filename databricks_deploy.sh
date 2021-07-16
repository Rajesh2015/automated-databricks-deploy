#!/bin/bash
echo "Prerequisites:"
echo "Docker must be installed (https://docs.docker.com/docker-for-windows/install/)"
echo "You must be logged in to a Docker repo (docker login)"
echo "You must have docker cli installed and profile used here should be configured using docker configure"
#---------------------------------
export docker_username
export repository_name
export version
#--------------------------------
#Read scala version from sbt

sbt_value="$(sbt -Dsbt.supershell=false -error "print version" "print name" "print scalaVersion")"
version=$(echo $sbt_value |awk -F ' ' '{print $1}')
imagename=$(echo $sbt_value |awk -F ' ' '{print $2}')
scala_version=$(echo $sbt_value |awk -F ' ' '{print $3}'|awk -F '.' '{print $1 "."$2}')
repository_name=$imagename
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
y#import yml parsing script
source $parent_path/parse_yaml.sh
#
#
#echo ${project_name}
#Jump to function for better control
function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

function strip_quotes() {
    local -n var="$1"
    [[ "${var}" == \"*\" || "${var}" == \'*\' ]] && var="${var:1:-1}"
}
function remove_end_comma(){
 echo $(echo $1 | sed 's/\(.*\),/\1 /')
}
#Init jumpto
start=${1:-"start"}

jumpto $start

start:
filename="config.yml"
read -p "Please enter the configuration yml file name $f [eg:$filename]:" userinputname

if [ ! -z "$userinputname" -a "$userinputname" != " " ]; then
filename=$userinputname
fi
if [ -e $parent_path/${filename} ]
then
eval $(parse_yaml $parent_path/${filename} "config_")
else
echo "No file with ${filename} name exists.Exiting..."
jumpto end
fi

#Setting all required values from yaml
docker_username=$config_dockerusername
strip_quotes docker_username
cluster_name=$docker_username/$repository_name/$version
url=$docker_username/$repository_name":latest"

function check_status()
{
  if [ $? -eq 0 ]
then
  echo "Succeeded "
else
  echo "Something went wrong while executing steps: Exiting...." >&2
  jumpto end
fi
}

read -p "Do you want to clean and build the project.Pressing no will skip creation of container too and use the exiting container in dockerhub$build? [y/n]" answer
#
if [[ ${answer} = y ]]; then
sbt clean package copyJarsTask
check_status
else
jumpto createcluster
fi
#
read -p "Do you want to build and push the container to docker hub $f? [y/n]" answer

if [[ ${answer} = y ]]; then
read -p "Enter the image name [${imagename}] : $name" imagename
#Copy docker file
$(cp  $parent_path/Dockerfile $(pwd))
docker build  --build-arg scalaversion="scala-${scala_version}" --no-cache -t imagename:local .
check_status
fi

deploy:
#Running deploy script
echo "Creating tag and pushing  the container to dockerhub"
bash  $parent_path/deploy.sh



createcluster:
echo "Creating cluster"
#Set runtime in databricks

if [ "$scala_version" == 2.11 ]
then
runtime="6.4.x-esr-scala2.11"
elif [ "$scala_version" == 2.12 ]
then
runtime="7.3.x-scala2.12"
else
echo "Not Supported"
jumpto end
fi
#Create the databricks config json file
function create_databricks_config_json()
{
    {
echo '{
    "autoscale": {
    "min_workers":' \"$config_min_workers\"',
    "max_workers":' \"$config_max_workers\" '},
    "cluster_name"': \"$cluster_name\"',
    "spark_version"': \"$runtime\"',
     "aws_attributes": {
     "zone_id"': $config_zone_id ',
     "instance_profile_arn":' $(remove_end_comma  "$config_roles_instance_profile_arn") '},
     "node_type_id":' $config_node_type_id',
     "autotermination_minutes":' \"$config_autotermination_minutes\"',
     "driver_node_type_id":' $config_driver_node_type_id',
     "docker_image": {
      "url":' \"$url\" '},'
    }>> databricks_cluster.json
    profile=$config_databricks_profile
    strip_quotes profile
     if [[ $profile != "DEV"  ]]; then
       echo '"spark_env_vars":{
        "AWS_STS_REGIONAL_ENDPOINTS": "regional"}'>> databricks_cluster.json
      fi
    asuumerolearn=$config_roles_assume_role_arn
        strip_quotes asuumerolearn
    if [ ! -z "$asuumerolearn" -a "$asuumerolearn" != " " ]; then
     echo '"spark_conf": {
    "spark.hadoop.fs.s3a.impl": "com.databricks.s3a.S3AFileSystem",
     "spark.hadoop.fs.s3n.impl": "com.databricks.s3a.S3AFileSystem",
     "spark.hadoop.fs.s3a.credentialsType": "AssumeRole",
     "spark.hadoop.fs.s3a.stsAssumeRole.arn":' $config_roles_assume_role_arn ',
     "spark.hadoop.fs.s3.impl": "com.databricks.s3a.S3AFileSystem"
     },'>> databricks_cluster.json
    fi
    echo  '}'>> databricks_cluster.json
}

#Create cluster with specified name
function create_cluster(){
create_databricks_config_json
profile_name=$config_databricks_profile
strip_quotes profile_name
databricks clusters create --json-file databricks_cluster.json --profile $profile_name
check_status
cluster_status=$(databricks clusters get --cluster-name "$cluster_name")
if [ ! -z "$cluster_status" -a "$cluster_status" != " " ]; then
echo "### Cluster created sucessfully with below information ###"
echo "$cluster_status"
fi

}

#delete the cluster if exits and recreates with  new docker image
function delete_create_cluster(){
#  set -x
cluster_id=$1
profile=$config_databricks_profile
strip_quotes profile
echo "cluster ${cluster_id}"
databricks clusters permanent-delete --cluster-id $cluster_id --profile $profile
create_cluster
}

cluster_id=""

read -p "Create Databricks cluster and deploy docker image $cluster? [y/n]" answer

if [[ ${answer} = y ]]; then
cluster_id=$(databricks clusters get --cluster-name "$cluster_name" | grep -oP '(?<="cluster_id": ")[^"]*')
else
jumpto end
fi
if [[ -z "$cluster_id" ]]; then
echo "Creating cluster"
create_cluster
else
echo "Cluster already  exist with name $cluster_name and id  ${cluster_id} Deleting and recreating"
delete_create_cluster "$cluster_id"
fi
#End of script
end:
echo "Cleaning up"
#Cleanup the jars
sbt deleteJarsTask
##remove json file
if [ -e databricks_cluster.json ]
then
rm databricks_cluster.json
fi
##remove dockerfile file
if [ -e Dockerfile ]
then
rm Dockerfile
fi
exit 1
