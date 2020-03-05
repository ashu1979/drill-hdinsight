#!/bin/bash
set -eux

ISSUPPORTED=$(echo -e "import hdinsight_common.ClusterManifestParser as ClusterManifestParser\nprint ClusterManifestParser.parse_local_manifest().settings.get('enable_security') == 'false' and ClusterManifestParser.parse_local_manifest().settings.get('cluster_type') == 'hadoop'" | python) 
if [[ "$ISSUPPORTED" != "True" ]]; then 
  echo "Drill installation is only supported on hadoop cluster types. Other cluster types (Spark, Kafka, Secure Hadoop etc are not supported yet. Aborting." ; 
  exit 1
fi

VERSION=1.17.0
DRILL_BASE_DIR=/var/lib/drill

if [[ -n $1 ]]; then
    VERSION=$1
fi    

mkdir -p $DRILL_BASE_DIR
chmod -R 777 $DRILL_BASE_DIR

cd $DRILL_BASE_DIR

wget "http://apache.mirrors.hoobly.com/drill/drill-"$VERSION/apache-drill-"$VERSION.tar.gz"""

DRILLDIR="apache-drill-$VERSION"
FULL_PATH=${DRILL_BASE_DIR}/${DRILLDIR}

tar -xzvf $DRILLDIR.tar.gz

mkdir -p $FULL_PATH/jars/3rdparty
cd $FULL_PATH/jars/3rdparty

wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/3.2.1/hadoop-azure-3.2.1.jar
wget https://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/8.6.0/azure-storage-8.6.0.jar

cd $FULL_PATH/jars

wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/3.2.1/hadoop-azure-datalake-3.2.1.jar
wget https://repo1.maven.org/maven2/com/microsoft/azure/azure-data-lake-store-sdk/2.3.8/azure-data-lake-store-sdk-2.3.8.jar

cp /usr/lib/hdinsight-logging/microsoft-log4j-etwappender-*.jar $FULL_PATH/jars/classb

cd $FULL_PATH/conf
rm -f ./logback.xml
wget https://raw.githubusercontent.com/yaron2/hdinsight-drill/master/logback.xml 

cd $DRILL_BASE_DIR

ZKHOSTS=`grep -R zookeeper /etc/hadoop/conf/yarn-site.xml | grep 2181 | grep -oPm1 "(?<=<value>)[^<]+"`
if [ -z "$ZKHOSTS" ]; then
    ZKHOSTS=`grep -R zk /etc/hadoop/conf/yarn-site.xml | grep 2181 | grep -oPm1 "(?<=<value>)[^<]+"`
fi

sed -i "s@localhost:2181@$ZKHOSTS@" $DRILLDIR/conf/drill-override.conf
ln -s /etc/hadoop/conf/core-site.xml $DRILLDIR/conf/core-site.xml
$DRILLDIR/bin/drillbit.sh restart

cd $FULL_PATH

STATUS=$(./bin/drillbit.sh status)
echo $STATUS
if [[ $STATUS != "drillbit is running." ]]; then
	>&2 echo "Drill installation failed"
	exit 1
fi
