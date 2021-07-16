# README #
shell scripts to deploy a Scala project to a Databricks cluster.
# Prerequisites
- Docker must be installed (https://docs.docker.com)
- You must be logged in to a Docker repo (docker login)
- Python must be installed (https://www.python.org/ftp/python/3.6.4/python-3.6.4.exe)
- Databricks cli must be installed (pip install databricks-cli)
- Databricks cli must be configured (databricks configure)
- If you are using STS assume roles to access AWS S3 buckets from Databricks, you need the ARN of instance profile role and the assume role (1 time per profile)
- Make sure to update the build.sbt with below tasks
```
val copyJarsTask = taskKey[Unit]("copy-jars")
copyJarsTask := {
  val folder = new File("lib/jars")
  //Find the relevant Jars
  val requiredLib= libraryDependencies.value.filter(v=>(!v.toString().contains("test"))
    &&(!v.toString().contains("org.apache.spark"))
    &&(!v.toString().contains("scala-library")))
    .map(v=>
    {val arr=v.toString().split(":")
      (arr(1)+"_"+scalaVersion.value.substring(0,4)+"-"+arr(2)+".jar",arr(1)+"-"+arr(2)+".jar")
    })
  (managedClasspath in Compile).value.files.map { f =>
    requiredLib.map(name=>{
  if(f.getName.equalsIgnoreCase(name._1)||f.getName.equalsIgnoreCase(name._2))
    IO.copyFile(f, folder / f.getName)
    })
  }
}

val deleteJarsTask = taskKey[Unit]("delete-jars")
deleteJarsTask := {
  val folder = new File("lib/jars")
  IO.delete(folder)

}
```
- All your settings can be put inside a config.yaml file like below(Applicable only for shell script).
```
ORGANIZATION : <orgnaziation docker hub name>
REPOSITORY_NAME : <repositort name>
VERSION : <version of repository>
clustername: "<enter cluster name>"
databricks_profile: "<enter profile>"
roles: {
 instance_profile_arn: "<enter role>"
 assume_role_arn: "<enter role>"
}
zone_id: "<enter region>"
min_workers: "<min workers>"
max_workers: "<max workers>"
spark_version: "<spark version in cluster>"
node_type_id : "<node type>"
autotermination_minutes: "<time out>"
driver_node_type_id : "<driver node type>"
docker_image_url : "<docker image path>"

```
# Usage of shell script
- Go to the root folder of your project.
- Run databricks_deploy.sh  and follow instructions
- It will create docker image with all required dependencies and create the databricks cluster for you
