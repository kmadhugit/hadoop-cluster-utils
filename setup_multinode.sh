#!/bin/bash -l

# Need to create user manually
# Need to set JAVA_HOME in .bashrc files on all machines
# Need to complete ssh setup for all servers

ul=`tput smul`
nul=`tput rmul`

CURDIR=`pwd`            # Inside hadoop-cluster-utils directory where run.sh is exist
WORKDIR=${HOME}         # where hadoop and spark package will download 

current_time=$(date +"%Y.%m.%d.%S")

if [ ! -d $CURDIR/logs ];
then
  mkdir logs
fi

log=`pwd`/logs/hadoop_cluster_utils_$current_time.log

if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    echo JAVA_HOME found, java executable in $JAVA_HOME
    echo "---------------------------------------------"    
else
    echo "JAVA_HOME not found in your environment, please set the JAVA_HOME variable in your environment then continue to run this script."
    exit 1 
fi

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
            exit 1
        fi
      fi
   done

   # Validation for hadoop port instances

   declare -a port_name=("NAMENODE_PORT" "NAMENODE_HTTP_ADDRESS" "NAMENODE_SECONDARY_HTTP_ADDRESS" "NAMENODE_SECONDARY_HTTPS_ADDRESS" "DATANODE_ADDRESS" "DATANODE_HTTP_ADDRESS" "DATANODE_IPC_ADDRESS" "MAPREDUCE_JOBHISTORY_ADDRESS" "MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS" "MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS" "RESOURCEMANAGER_SCHEDULER_ADDRESS" "RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS" "RESOURCEMANAGER_ADDRESS" "RESOURCEMANAGER_ADMIN_ADDRESS" "RESOURCEMANAGER_WEBAPP_ADDRESS" "NODEMANAGER_LOCALIZER_ADDRESS" "NODEMANAGER_WEBAPP_ADDRESS")

   declare -a port_list=("$NAMENODE_PORT" "$NAMENODE_HTTP_ADDRESS" "$NAMENODE_SECONDARY_HTTP_ADDRESS" "$NAMENODE_SECONDARY_HTTPS_ADDRESS" "$DATANODE_ADDRESS" "$DATANODE_HTTP_ADDRESS" "$DATANODE_IPC_ADDRESS" "$MAPREDUCE_JOBHISTORY_ADDRESS" "$MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS" "$MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS" "$RESOURCEMANAGER_SCHEDULER_ADDRESS" "$RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS" "$RESOURCEMANAGER_ADDRESS" "$RESOURCEMANAGER_ADMIN_ADDRESS" "$RESOURCEMANAGER_WEBAPP_ADDRESS" "$NODEMANAGER_LOCALIZER_ADDRESS" "$NODEMANAGER_WEBAPP_ADDRESS")

   i=0
   for j in "${port_list[@]}";
   do
      sudo netstat -pnlt | grep $j > /dev/null
      if [ $? -eq 0 ];
      then
         echo "${port_name[i]} running on port $j" >> temp
      fi
      i=$i+1
    done

    if [ -f temp ];
    then
       cat temp
       cat temp &>> $log
       echo "Kindly kill above running instance(s) else change port number in config.sh file, then continue to run this script."
       echo "Kindly kill above running instance(s) else change port number in config.sh file, then continue to run this script." &>> $log
       rm temp &>> $log
       exit 1
    fi
   
   
  # Slicing MASTERIP
  MASTERIP=`cat ${CURDIR}/config.sh | grep MASTER | cut -d "=" -f2`
  
  # Adding slave machine names to slave file
 
  echo "`cat ${CURDIR}/config.sh | grep SLAVES | grep -v ^# |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1 `" >${CURDIR}/conf/slaves

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

  
  # Download and install hadoop For Master machine installation
  
  echo "***********************************************"
  echo "${ul}Download and install hadoop...${nul}"
  cd ${WORKDIR}
  if [ ! -d ${WORKDIR}/hadoop-${hadoopver} ];
  then
     if curl --output /dev/null --silent --head --fail "http://www-us.apache.org/dist/hadoop/common/hadoop-${hadoopver}/hadoop-${hadoopver}.tar.gz"
      then
        echo "Hadoop file Downloading on Master"
	    # wget http://www-us.apache.org/dist/hadoop/common/hadoop-${hadoopver}/hadoop-${hadoopver}.tar.gz 
          
     else
        echo "This URL Not Exist. Please check your hadoop version then continue to run this script."
        exit 1
     fi 
   fi	

	  
	  # Copying hadoop tgz file , unzipping and exporting paths in the .bashrc file on all machines
	  	  
	for i in `cat ${CURDIR}/config.sh | grep SLAVES | grep -v ^# |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
	do 
	 echo "Copying Hadoop file to  machines $i and unzipping"
	 #scp ${WORKDIR}/hadoop-${hadoopver}.tar.gz @$i:${WORKDIR}
	 ssh $i "tar xf hadoop-*.tar.gz --gzip"
	 
	     echo "Updating hadoop variables machines $i "
		 
	     export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}
	     echo "#StartHadoopEnv"> tmp_b
         echo "export CURDIR="${CURDIR}"" >> tmp_b
         echo "export PATH="${CURDIR}":"${CURDIR}"/hadoop:\$PATH" >> tmp_b 
		 echo "export PATH="${CURDIR}":"${CURDIR}"/utils:\$PATH" >> tmp_b
         echo "export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}" >> tmp_b
         echo "export HADOOP_PREFIX=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_MAPRED_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_COMMON_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_HDFS_HOME=$HADOOP_HOME" >> tmp_b
         echo "export YARN_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> tmp_b
         echo "export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> tmp_b
         echo "export PATH=$HADOOP_HOME/bin:\$PATH" >> tmp_b
         echo "#StopHadoopEnv">> tmp_b
	 
	 scp tmp_b @$i:${WORKDIR} &>>/dev/null
	 
     ssh $i "grep -q '#StartHadoopEnv' $HOME/.bashrc"
     if [ $? -ne 0 ];
      then
	     ssh $i "cat tmp_b>>$HOME/.bashrc"
		 ssh $i "rm tmp_b"

      else
         ssh $i "sed -i '/#StartHadoopEnv/,/#StopHadoopEnv/d' $HOME/.bashrc"
		 ssh $i "cat tmp_b>>$HOME/.bashrc"
		 ssh $i "rm tmp_b"
     fi
	 ssh $i "source ~/.bashrc" &>>/dev/null
   done
   
   rm -rf tmp_b
	
	
	echo "***********************************************"  
	## Configuration changes in hadoop-clusterfor Core-site,hdfs-site and mapred-site xml
	
     echo "Started configuration properties in hadoop-cluster CURDIR for Core-site,hdfs-site and mapred-site xml"

      if [ ! -f ${CURDIR}/conf/core-site.xml ];
         then
         cp ${CURDIR}/conf/core-site.xml.template ${CURDIR}/conf/core-site.xml
         cp ${CURDIR}/conf/hdfs-site.xml.template ${CURDIR}/conf/hdfs-site.xml
         cp ${CURDIR}/conf/mapred-site.xml.template ${CURDIR}/conf/mapred-site.xml
                  
       
         # core-site.xml configuration configuration properties
         sed -i 's|HADOOP_TMP_DIR|'"$HADOOP_TMP_DIR"'|g' ${CURDIR}/conf/core-site.xml
         sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/core-site.xml
         sed -i 's|NAMENODE_PORT|'"$NAMENODE_PORT"'|g' ${CURDIR}/conf/core-site.xml
		 
           
         # hdfs-site.xml configuration properties
         sed -i 's|REPLICATION_VALUE|'"$REPLICATION_VALUE"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|NAMENODE_DIR|'"$NAMENODE_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|DATANODE_DIR|'"$DATANODE_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|NAMENODE_HTTP_ADDRESS|'"$NAMENODE_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|NAMENODE_SECONDARY_HTTP_ADDRESS|'"$NAMENODE_SECONDARY_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|NAMENODE_SECONDARY_HTTPS_ADDRESS|'"$NAMENODE_SECONDARY_HTTPS_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|DATANODE_ADDRESS|'"$DATANODE_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|DATANODE_HTTP_ADDRESS|'"$DATANODE_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
         sed -i 's|DATANODE_IPC_ADDRESS|'"$DATANODE_IPC_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml

  
         # mapred-site.xml configuration properties
         sed -i 's|MAPREDUCE_JOBHISTORY_ADDRESS|'"$MAPREDUCE_JOBHISTORY_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
         sed -i 's|MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS|'"$MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
         sed -i 's|MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS|'"$MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
  
         echo "Finished configuration properties for Core-site,hdfs-site and mapred-site xml files"
      fi  
      
   
     echo "***********************************************"

## yarn-site.xml configuration properties and hadoop-env.sh file updates for all machines

   
	for i in `cat ${CURDIR}/config.sh | grep SLAVES | grep -v ^# |cut -d "=" -f2 | tr "%" "\n" `
    do
	     freememory=`echo $i| cut -d "," -f2`
		 memorypercent=`echo $i| cut -d "," -f3`	
		 ncpu=`echo $i| cut -d "," -f4`
		 slaveip=`echo $i| cut -d "," -f1`
		 
		 echo "Started updating configuration properties for yarn-sites and hadoop.env.sh for $slaveip \n"
		 
		 cp ${CURDIR}/conf/yarn-site.xml.template ${CURDIR}/conf/yarn-site.xml
		 sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_MB|'"$YARN_SCHEDULER_MIN_ALLOCATION_MB"'|g' ${CURDIR}/conf/yarn-site.xml
		 sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_MB|'"$freememory"'|g' ${CURDIR}/conf/yarn-site.xml
		 sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_VCORES|'"$YARN_SCHEDULER_MIN_ALLOCATION_VCORES"'|g' ${CURDIR}/conf/yarn-site.xml
		 sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_VCORES|'"$ncpu"'|g' ${CURDIR}/conf/yarn-site.xml
		 sed -i 's|YARN_NODEMANAGER_RESOURCE_CPU_VCORES|'"$ncpu"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|YARN_NODEMANAGER_RESOURCE_MEMORY_MB|'"$memorypercent"'|g' ${CURDIR}/conf/yarn-site.xml
		 sed -i 's|RESOURCEMANAGER_SCHEDULER_ADDRESS|'"$RESOURCEMANAGER_SCHEDULER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS|'"$RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|RESOURCEMANAGER_ADDRESS|'"$RESOURCEMANAGER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|RESOURCEMANAGER_ADMIN_ADDRESS|'"$RESOURCEMANAGER_ADMIN_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|RESOURCEMANAGER_WEBAPP_ADDRESS|'"$RESOURCEMANAGER_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|NODEMANAGER_LOCALIZER_ADDRESS|'"$NODEMANAGER_LOCALIZER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
         sed -i 's|NODEMANAGER_WEBAPP_ADDRESS|'"$NODEMANAGER_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
		 
		 
	     scp ${CURDIR}/conf/*site.xml @$slaveip:$HADOOP_HOME/etc/hadoop
		 
		 ## logic to update java version in hadoop-env.sh file on all machines
		 
		 JAVA_HOME_SLAVE=$(ssh $slaveip 'grep JAVA_HOME ~/.bashrc | grep -v "PATH" | cut -d"=" -f2')
		 echo "sed -i 's|"\${JAVA_HOME}"|"${JAVA_HOME_SLAVE}"|g' $HADOOP_HOME/etc/hadoop/hadoop-env.sh" | ssh $slaveip bash
         echo "---------------------------------------------"
		 
	done	 
	rm -rf ${CURDIR}/conf/*site.xml
 	echo "***********************************************"

#Updating the slave file on master 
 
   cp ${CURDIR}/conf/slaves ${HADOOP_HOME}/etc/hadoop
     
 #--  
else
    echo "Config file does not exist. Please check README.md for installation steps." 
    exit 1
fi  # Line 54 if condtion 

#--------------------------------------------------------------------------------
# Spark installation

echo -n "Download and install Spark ... "
cd ${WORKDIR}
if [ ! -d ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3} ];
then
  if curl --output /dev/null --silent --head --fail "http://www-us.apache.org/dist/spark/spark-${sparkver}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz"
  then
    #wget http://www-us.apache.org/dist/spark/spark-${sparkver}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz 
    echo "Spark copy downloaded on Master "
  else 
    echo "This URL Not Exist. Please check your spark version then continue to run this script."
    exit 1
  fi 
echo "***********************************************"
#echo "Export SPARK_HOME to the PATH and Add scripts to the PATH

   for slaveip in `cat ${CURDIR}/config.sh | grep SLAVES | grep -v ^# |cut -d "=" -f2 | tr "%" "\n" |cut -d "," -f1`
    do
	    echo "Started updating .bashrc file on $slaveip with Spark variables "
		scp ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz @$slaveip:${WORKDIR} &>> $log
		ssh $slaveip "tar xf spark*.tgz --gzip" &>> $log	
		
		echo '#StartSparkEnv' >tmp_b
		echo "export SPARK_HOME="${WORKDIR}"/spark-"${sparkver}"-bin-hadoop"${hadoopver:0:3}"" >>tmp_b
		echo "export PATH=\$SPARK_HOME/bin:\$PATH">>tmp_b
		echo '#StopSparkEnv'>>tmp_b
		
		scp tmp_b @$slaveip:${WORKDIR}&>>/dev/null
		
		ssh $slaveip "grep -q "SPARK_HOME" ~/.bashrc"
		if [ $? -ne 0 ];
		then
		
	     ssh $slaveip "cat tmp_b>>$HOME/.bashrc"
		 ssh $slaveip "rm tmp_b"
		   
		else
		 
		 ssh $slaveip "sed -i '/#StartSparkEnv/,/#StopSparkEnv/ d' $HOME/.bashrc"
	     ssh $slaveip "cat tmp_b>>$HOME/.bashrc"
		 ssh $slaveip "rm tmp_b"
		 
		fi

	 ssh $slaveip "source ~/.bashrc"
		
	done
fi	


## updating Slave file for Spark folder

cp spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves.template spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves
sed -i 's|localhost||g' spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves
cat ${CURDIR}/conf/slaves>>spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves

echo -e "\nFinished export SPARK_HOME into .bashrc file"
echo -e "Spark installation done..!!\n\n"
#----

## to clear stranded processes if exists ( this part can be removed if setup is getting done for first time)
for slaveip in `cat ${CURDIR}/config.sh | grep SLAVES | grep -v ^# |cut -d "=" -f2 | tr "%" "\n" |cut -d "," -f1`
do
ssh $slaveip 'rm -rf /tmp/*' &>>/dev/null
done 
source ${WORKDIR}/.bashrc

##to start hadoop setup

$HADOOP_PREFIX/bin/hdfs namenode -format
$CURDIR/hadoop/start-all.sh
$CURDIR/utils/checkall.sh

# use stop-all.sh for stopping

echo "${ul}Web URL link${nul}"
echo "HDFS web address : http://"$MASTER":"$NAMENODE_HTTP_ADDRESS""
echo "Resource Manager : http://"$MASTER":"$RESOURCEMANAGER_WEBAPP_ADDRESS"/cluster"


# echo "${ul}Ensure SPARK running correctly using following command${nul}"
# echo "${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10"
# echo -e 
# read -p "Do you wish to run above command ? [y/N] " prompt


# if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
# then
  # ${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10 &>> $log
# else
  # echo "Thanks for your response"
# fi



# grep -r 'Pi is roughly' ${log}
# if [ $? -eq 0 ];
# then
   # echo "Spark services running. Please check log file for more details."
# else
   # echo "Expected output not found. Please check log file for more details."
# fi
