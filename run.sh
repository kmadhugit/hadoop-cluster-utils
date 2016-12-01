#!/bin/bash -l

# Need to create user manually
# Need to set JAVA_HOME

ul=`tput smul`
nul=`tput rmul`

if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    echo JAVA_HOME found, java executable in $JAVA_HOME    
else
    echo "JAVA_HOME not found in your environment, please set the JAVA_HOME variable in your environment then continue to run this script."
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
  
  { cat ${CURDIR}/config.sh; echo; } | while read -r line; do
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
  
  for (( i=1; i<${SLAVELIST}+1; i++ ));
  do
      echo "`cat ${CURDIR}/config.sh | grep SLAVES | cut -d "=" -f2 |  cut -d'&' -f$i | cut -d',' -f1`" >> ${CURDIR}/conf/slaves
  done
  
  # Validation for IPs
  echo -e "${ul}Validation for slave IPs${nul}"
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
  
  echo -n "${ul}Download and install hadoop...${nul}"
  cd ${WORKDIR}
  if [ ! -d ${WORKDIR}/hadoop-${hadoopver} ];
  then
     if curl --output /dev/null --silent --head --fail "http://www-us.apache.org/dist/hadoop/common/hadoop-${hadoopver}/hadoop-${hadoopver}.tar.gz"
     then
         wget http://www-us.apache.org/dist/hadoop/common/hadoop-${hadoopver}/hadoop-${hadoopver}.tar.gz
         tar xf hadoop-${hadoopver}.tar.gz --gzip
     else
         echo "This URL Not Exist. Please check your hadoop version then continue to run this script."
		 exit 1
     fi 
   
      # export path to the .bashrc file
      grep "CURDIR" $HOME/.bashrc
      if [ $? -ne 0 ];
	  then
	     echo "export CURDIR="${CURDIR}"" >> $HOME/.bashrc
	     echo "export PATH="${CURDIR}"/CURDIR:"${CURDIR}"/hadoop:$PATH" >> $HOME/.bashrc 
	     echo "export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}" >> $HOME/.bashrc
	     echo "export HADOOP_PREFIX=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_COMMON_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_HDFS_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export YARN_HOME=\$HADOOP_HOME" >> $HOME/.bashrc
	     echo "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop" >> $HOME/.bashrc
	     echo "export YARN_CONF_DIR=\$HADOOP_HOME/etc/hadoop" >> $HOME/.bashrc
	     echo "export PATH="$HADOOP_HOME"/bin:$PATH" >> $HOME/.bashrc
      fi

  # Exporting PATH
  
  export CURDIR=${CURDIR}
  export PATH=${CURDIR}:${CURDIR}/hadoop:$PATH
  export HADOOP_HOME=${WORKDIR}/hadoop-${hadoopver}
  export HADOOP_PREFIX=$HADOOP_HOME
  export HADOOP_MAPRED_HOME=$HADOOP_HOME
  export HADOOP_COMMON_HOME=$HADOOP_HOME
  export HADOOP_HDFS_HOME=$HADOOP_HOME
  export YARN_HOME=$HADOOP_HOME
  export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
  export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop
  export PATH=$HADOOP_HOME/bin:$PATH
  

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
         sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/core-site.xml
         cp ${CURDIR}/conf/core-site.xml $HADOOP_HOME/etc/hadoop
         #CP ${CURDIR}/conf/core-site.xml $HADOOP_HOME/etc/hadoop
  
         # hdfs-site.xml configuration properties
         sed -i 's|REPLICATION_VALUE|'"$REPLICATION_FACTOR"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|NAMENODE_DIR|'"$DFS_NAMENODE_NAME_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|DATANODE_DIR|'"$DFS_DATANODE_NAME_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
         cp ${CURDIR}/conf/hdfs-site.xml $HADOOP_HOME/etc/hadoop
         #CP ${CURDIR}/conf/hdfs-site.xml $HADOOP_HOME/etc/hadoop
  
         # yarn-site.xml configuration properties
         sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/yarn-site.xml
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

echo "${ul}Following hadoop services are running currently${nul}"
jps
echo "${ul}Web URL link${nul}"
echo "HDFS web address : http://"$MASTER":50070"
echo "Resource Manager : http://"$MASTER":8088/cluster"

# Spark installation

echo -n "Download and install Spark ... "
cd ${WORKDIR}
if [ ! -d ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3} ];
then
   if curl --output /dev/null --silent --head --fail "http://www-us.apache.org/dist/spark/spark-${sparkver}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz"
   then
     wget http://www-us.apache.org/dist/spark/spark-${sparkver}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz
     tar xf spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz --gzip
   else
     echo "This URL Not Exist. Please check your spark version then continue to run this script."
	 exit 1
   fi 
fi

echo "Export SPARK_HOME to the PATH"

# Add scripts to the PATH
grep "SPARK_HOME" ~/.bashrc
if [ $? -ne 0 ]; then
	echo "export SPARK_HOME="${WORKDIR}"/spark-"${sparkver}"-bin-hadoop"${hadoopver:0:3}"" >> ~/.bashrc
	echo "export PATH=\$SPARK_HOME/bin:$PATH" >> ~/.bashrc
fi

export SPARK_HOME=${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}
export PATH=$SPARK_HOME/bin:$PATH

echo -e "\nFinished export SPARK_HOME into .bashrc file"
echo -e "Spark installation done..!!\n\n"
echo "${ul}Ensure SPARK running correctly using following command${nul}"
echo "${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10"
echo -e 

read -p "Do you wish to run above command ? [y/N] " prompt

if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
  ${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10
else
  echo "Thanks for your response"
fi
