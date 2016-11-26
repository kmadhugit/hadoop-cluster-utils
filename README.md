# Hadoop and Yarn Setup

### Pre-requisities:
1. JAVA Setup should be completed and JAVA_HOME should be set in the environment variable.
2. Make sure the nodes are set for password-less SSH both ways(master->slaves & slaves->master).
3. Since we use the environment variables a lot in our scripts, make sure to comment out the portion following this statement in your ~/.bashrc , 
`If not running interactively, don't do anything`

### Installations:

* To automate hadoop installation follows the steps,

  ```bash
  git clone https://github.com/kmadhugit/hadoop-cluster-utils
  
  cd hadoop-cluster-utils  
  ```
  
* Configuration

   To configure `hadoop-cluster-utils`, copy `config.sh.template` to `config.sh` and edit that file.  See `config.sh.template` for detailed configuration instructions. After editing `config.sh`, execute `./run.sh` to run automate hadoop installation. 

* Ensure that the following java process is running in master. If not, check the log files
  
  ```
  NameNode
  JobHistoryServer
  ResourceManager
  ```
  Ensure that the following java process is running in slaves. If not, check the log files
  ```
  DataNode
  NodeManager
  ```
 
* HDFS, Resource Manager and Node Manager web Address
  
  ```
  HDFS web address : http://localhost:50070
  Resource Manager : http://localhost:8088/cluster
  Node Manager     : http://datanode:8042/node (For each node)
  ```
 
* Useful scripts
 
  ```
   > stop-all.sh #stop HDFS and Yarn
   > start-all.sh #start HDFS and Yarn
   > CP <localpath to file> <remotepath to dir> #Copy file from name nodes to all slaves
   > AN <command> #execute a given command in all nodes including master
   > DN <command> #execute a given command in all nodes excluding master
  ```