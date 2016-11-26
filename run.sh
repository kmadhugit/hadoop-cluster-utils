#!/bin/bash -l

# Need to create user manually
# Need to set JAVA_HOME

temp=0
temp=$(echo $JAVA_HOME)

if [ $temp -eq 0 ]; 
then
	echo "JAVA_HOME not found in your environment, please set the JAVA_HOME variable in your environment then continue to run this script."
	exit 1
else
	echo "JAVA_HOME found"
fi

CURDIR=`pwd`            # Inside hadoop-cluster-utils directory where run.sh is exist
WORKDIR=${HOME}         # where hadoop and spark package will download 

# Validation for config file

if [ -f ${CURDIR}/config.sh ]; 
then
  # First time permission set for config.sh file
  chmod +x config.sh
  source config.sh
  
  # Checking config file whether all fileds are filled
  
  { cat ${CURDIR}/hello; echo; } | while read -r line; do
	  if [[ $line =~ "=" ]] ;
	  then
	    confvalue=`echo $line |grep = | cut -d "=" -f2`
	    if [[ -z "$confvalue" ]];
		then
            echo "Configuration vlaue not set properly for $line, please check config.sh file"
		    exit
	    fi
	  fi
   done

  # Slicing MASTERIP
  MASTERIP=`cat ${CURDIR}/config.sh | grep MASTER | cut -d "=" -f2`
  
  # Counting number of SLAVEIP
  SLAVELIST=`cat ${CURDIR}/config.sh | grep SLAVES | cut -d "=" -f2 | tr "%" "\n" | wc -l`
  
  # Slicing SLAVEIP in list and save into slaves file
  declare -a SLAVEIP=()
  cd ${CURDIR}/conf
  rm slaves  
  for (( i=1; i<${SLAVELIST}+1; i++ ));
  do
      echo "`cat ${CURDIR}/config.sh | grep SLAVES | cut -d "=" -f2 |  cut -d'%' -f$i | cut -d',' -f1`" >> ${CURDIR}/conf/slaves
  done
  
  # Validation for IP
  while IFS= read -r ip; do
      if ping -q -c2 "$ip" &>/dev/null;
	  then
          echo "$ip is Pingable"
      else
          echo "$ip Not Pingable"
		  echo "Please check your config.sh file. $ip is not pingalbe."
		  exit 1
      fi
  done <${CURDIR}/conf/slaves
  
  
  # Download and install hadoop
  
  echo -n "Download and install hadoop ... "
  cd ${WORKDIR}
  if [ ! -d ${WORKDIR}/hadoop-2.7.3 ];
  then
      wget http://www-us.apache.org/dist/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz
      tar xf hadoop-2.7.3.tar.gz --gzip
   
      # export path to the .bashrc file
      grep "CURDIR" $HOME/.bashrc
      if [ $? -ne 0 ];
	  then
	     echo "export CURDIR="${CURDIR}"" >> $HOME/.bashrc
	     echo "export PATH="${CURDIR}"/CURDIR:"${CURDIR}"/hadoop:$PATH" >> $HOME/.bashrc 
	     echo "export HADOOP_HOME="${WORKDIR}"/hadoop-2.7.3" >> $HOME/.bashrc
	     echo "export HADOOP_PREFIX=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_COMMON_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_HDFS_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export YARN_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop" >> $HOME/.bashrc
	     echo "export YARN_CONF_DIR=\$HADOOP_HOME/etc/hadoop" >> $HOME/.bashrc
	     echo "export PATH="$HADOOP_HOME"/bin:$PATH" >> $HOME/.bashrc
      fi

      source $HOME/.bashrc

      # copy .bashrc to all other data nodes
      #CP $HOME/.bashrc $HOME
      #CP ${WORKDIR}/hadoop-2.7.3.tar.gz ${WORKDIR}
      #DN "tar xf hadoop-2.7.3.tar.gz --gzip"
      #scp -r /path/to/file username@hostname:/path/to/destination

      echo "Started configuration properties in hadoop CURDIR"

      if [ ! -f ${CURDIR}/conf/core-site.xml ];
	  then
         cp ${CURDIR}/conf/core-site.xml.template ${CURDIR}/conf/core-site.xml
         cp ${CURDIR}/conf/hdfs-site.xml.template ${CURDIR}/conf/hdfs-site.xml
         cp ${CURDIR}/conf/yarn-site.xml.template ${CURDIR}/conf/yarn-site.xml
		 
		 # Copy slaves file into HADOOP_HOME
		 cp ${CURDIR}/conf/slaves $HADOOP_HOME/etc/hadoop
		 #CP ${CURDIR}/conf/slaves $HADOOP_HOME/etc/hadoop
  
         # core-site.xml configuration configuration properties
         sed -i 's|HADOOP.TMP.DIR|'"$HADOOP_TMP_DIR"'|g' ${CURDIR}/conf/core-site.xml
         sed -i 's|YARN_RESOURCEMANAGER_HOSTNAME|'"$YARN_RESOURCEMANAGER_HOSTNAME"'|g' ${CURDIR}/conf/core-site.xml
         cp ${CURDIR}/conf/core-site.xml $HADOOP_HOME/etc/hadoop
         #CP ${CURDIR}/conf/core-site.xml $HADOOP_HOME/etc/hadoop
  
         # hdfs-site.xml configuration properties
         sed -i 's|REPLICATION_VALUE|'"$REPLICATION_FACTOR"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|NAMENODE_DIR|'"$DFS_NAMENODE_NAME_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|DATANODE_DIR|'"$DFS_DATANODE_NAME_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
         cp ${CURDIR}/conf/hdfs-site.xml $HADOOP_HOME/etc/hadoop
         #CP ${CURDIR}/conf/hdfs-site.xml $HADOOP_HOME/etc/hadoop
  
         # yarn-site.xml configuration properties
         sed -i 's|YARN_RESOURCEMANAGER_HOSTNAME|'"$YARN_RESOURCEMANAGER_HOSTNAME"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_MB|'"$YARN_SCHEDULER_MIN_ALLOCATION_MB"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_MB|'"$YARN_SCHEDULER_MAX_ALLOCATION_MB"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_VCORES|'"$YARN_SCHEDULER_MIN_ALLOCATION_VCORES"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_VCORES|'"$YARN_SCHEDULER_MAX_ALLOCATION_VCORES"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_NODEMANAGER_RESOURCE_CPU_VCORES|'"$YARN_NODEMANAGER_RESOURCE_CPU_VCORES"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_NODEMANAGER_RESOURCE_MEMORY_MB|'"$YARN_NODEMANAGER_RESOURCE_MEMORY_MB"'|g' ${CURDIR}/conf/yarn-site.xml
         cp ${CURDIR}/conf/yarn-site.xml $HADOOP_HOME/etc/hadoop
         #CP ${CURDIR}/conf/yarn-site.xml $HADOOP_HOME/etc/hadoop
  
         echo "Finished configuration properties in hadoop CURDIR and copied to $HADOOP_HOME/etc/hadoop"
      fi  
      
	  # Change the JAVA_HOME variable in hadoop-env.sh
      sed -i 's|${JAVA_HOME}|'"${JAVA_HOME}"'|g' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

      echo "Started creating directories"


      if [ ! -d "$HADOOP_TMP_DIR" ];
	  then
         # Creating directories
         mkdir -p $HADOOP_TMP_DIR
         #DN "mkdir -p $HADOOP_TMP_DIR"
         mkdir -p $DFS_NAMENODE_NAME_DIR
         #DN "mkdir -p $DFS_NAMENODE_NAME_DIR"
         mkdir -p $DFS_DATANODE_NAME_DIR
         #DN "mkdir -p $DFS_DATANODE_NAME_DIR"
         echo "Finished creating directories"
  
         echo "Formated NAMENODE"
         $HADOOP_PREFIX/bin/hdfs namenode -format mycluster
      fi
  fi    
else
    echo "Config file does not exist. Please check README.md for installation steps." 
    exit 1
fi  # Line 54 if condtion 

$HADOOP_PREFIX/sbin/start-all.sh
# use stop-all.sh for stopping


# Ensure all nodes are running correctly.
AN jps
echo "HDFS web address : http://localhost:50070"
echo "Resource Manager : http://localhost:8088/cluster"
echo "Node Manager     : http://datanode:8042/node (For each node)"

# Spark installation

echo -n "Download and install Spark ... "
cd ${WORKDIR}
if [ ! -d ${WORKDIR}/spark-2.0.1-bin-hadoop2.7 ];
then
   wget http://www-us.apache.org/dist/spark/spark-2.0.1/spark-2.0.1-bin-hadoop2.7.tgz
   tar xf spark-2.0.1-bin-hadoop2.7.tgz --gzip
fi

echo "Export SPARK_HOME to the PATH"

# Add scripts to the PATH
grep "SPARK_HOME" ~/.bashrc
if [ $? -ne 0 ]; then
	echo "export SPARK_HOME="${WORKDIR}"/spark-2.0.1-bin-hadoop2.7" >> ~/.bashrc
	echo "export PATH=\$SPARK_HOME/bin:$PATH" >> ~/.bashrc
fi

source $HOME/.bashrc

echo "Finished export SPARK_HOME into .bashrc file"
echo "Spark installation done..!!"
echo "Fully completed..!!"
