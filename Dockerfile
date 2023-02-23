FROM gethue/hue

USER root
RUN sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
RUN sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
# set mysql password without prompt
RUN  apt-get update && apt-get install -y debconf-utils apt-utils && \
echo mysql-server-5.7 mysql-server/root_password password root | debconf-set-selections && \
echo mysql-server-5.7 mysql-server/root_password_again password root | debconf-set-selections && \
apt-get install -y mysql-server -o pkg::Options::="--force-confdef" -o pkg::Options::="--force-confold" --fix-missing

ENV DEBIAN_FRONTEND=noninteractive
RUN apt install -y software-properties-common && sudo add-apt-repository universe
RUN apt update && apt-get install -y --no-install-recommends build-essential gcc openjdk-8-jdk net-tools vim wget telnet iputils-ping \
openssh-server openssh-client python python-dev ca-certificates python-pip-whl libmariadb-java libslf4j-java tzdata && \
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py && \
python2 get-pip.py && \
rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
RUN echo "Asia/Shanghai" > /etc/timezone && \
rm -f /etc/localtime  && \
dpkg-reconfigure -f noninteractive tzdata


# add all packages
ADD packages/*gz /usr/local/
# zookeeper
# RUN mv /usr/local/apache-zookeeper-3.5.6-bin /usr/local/zookeeper
RUN wget https://archive.apache.org/dist/zookeeper/zookeeper-3.5.6/apache-zookeeper-3.5.6-bin.tar.gz && \
    tar -xzvf apache-zookeeper-3.5.6-bin.tar.gz && \
    mv apache-zookeeper-3.5.6-bin /usr/local/zookeeper
RUN mkdir /var/lib/zookeeper
RUN sed "s#/tmp/zookeeper#/var/lib/zookeeper#" /usr/local/zookeeper/conf/zoo_sample.cfg > /usr/local/zookeeper/conf/zoo.cfg


# hadoop
RUN wget https://archive.apache.org/dist/hadoop/core/hadoop-3.1.4/hadoop-3.1.4.tar.gz && \
    tar -xzvf hadoop-3.1.4.tar.gz && \
    mv hadoop-3.1.4 /usr/local/hadoop
RUN ln -s /usr/local/hadoop/etc/hadoop /etc/hadoop
RUN mkdir -p /usr/local/hadoop/data/{namenode,datanode} /etc/hadoop-httpfs/conf/

RUN echo "\nStrictHostKeyChecking no\nUserKnownHostsFile" >> /etc/ssh/ssh_config && \
addgroup hadoop && \
adduser --ingroup hadoop --quiet --disabled-password hadoop && \
echo "hadoop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
su hadoop -c "ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 0600 ~/.ssh/authorized_keys" && \
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /etc/hadoop/hadoop-env.sh && \
echo "bigdata" > /etc/hadoop/workers && \
chown -R hadoop:hadoop /usr/local/hadoop


ENV HADOOP_HOME=/usr/local/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV HADOOP_MAPRED_HOME=${HADOOP_HOME}
ENV HADOOP_COMMON_HOME=${HADOOP_HOME}
ENV HADOOP_HDFS_HOME=${HADOOP_HOME}
ENV YARN_HOME=${HADOOP_HOME}
ENV HADOOP_COMMON_LIB_NATIVE_DIR=${HADOOP_HOME}/lib/native
ENV HADOOP_OPTS="-Djava.library.path=${HADOOP_HOME}/lib"
#ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:$PATH
ADD conf/hadoop /etc/hadoop
ADD conf/httpfs/httpfs-site.xml /etc/hadoop-httpfs/conf/
ADD mysql-connector-java.jar /usr/share/java/mysql-connector-java.jar
# Spark
RUN wget https://archive.apache.org/dist/spark/spark-2.4.7/spark-2.4.7-bin-hadoop2.7.tgz && \
    tar -xvf spark-2.4.7-bin-hadoop2.7.tgz && \
    mv spark-2.4.7-bin-hadoop2.7 /usr/local/spark
RUN ln -s /usr/local/spark/conf /etc/spark
ADD conf/spark /etc/spark
RUN cp /usr/local/spark/conf/log4j.properties.template /usr/local/spark/conf/log4j.properties
RUN ln -s /usr/share/java/mysql-connector-java.jar /usr/local/spark/jars/mysql-connector-java.jar
RUN ln -s /usr/local/hive/conf/hive-site.xml /usr/local/spark/conf/hive-site.xml
RUN sed -i 's/log4j.rootCategory=INFO, console/log4j.rootCategory=WARN,console/' /usr/local/spark/conf/log4j.properties

# Kafka
RUN wget https://archive.apache.org/dist/kafka/2.3.1/kafka_2.11-2.3.1.tgz && \
    tar -xvf kafka_2.11-2.3.1.tgz && \
    mv kafka_2.11-2.3.1 /usr/local/kafka
RUN ln -s /usr/local/kafka/config /etc/kafka
ADD conf/kafka/server.properties /etc/kafka
RUN mkdir /usr/local/kafka/data /usr/local/kafka/log

# Tez
RUN wget https://downloads.apache.org/tez/0.9.2/apache-tez-0.9.2-bin.tar.gz && \
    tar -xzvf apache-tez-0.9.2-bin.tar.gz && \
    mv apache-tez-0.9.2-bin /usr/local/tez
RUN ln -s /usr/local/tez/conf /etc/tez
ENV TEZ_HOME=/usr/local/tez

# Hive
RUN wget https://downloads.apache.org/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz && \
    tar -xzvf apache-hive-3.1.2-bin.tar.gz && \
    mv apache-hive-3.1.2-bin /usr/local/hive
RUN ln -s /usr/local/hive/conf /etc/hive
ADD conf/hive /etc/hive
RUN ln -s /usr/share/java/mysql-connector-java.jar  /usr/local/hive/lib/mysql-connector-java.jar
RUN rm /usr/local/hive/lib/guava-19.0.jar
RUN cp /usr/local/hadoop/share/hadoop/hdfs/lib/guava-27.0-jre.jar /usr/local/hive/lib
ENV HIVE_HOME=/usr/local/hive
ENV HIVE_CONF_DIR=/etc/hive

# Hue
ADD conf/hue /usr/share/hue/desktop/conf

# MySQL
RUN chown -R mysql:mysql /var/lib/mysql

# Flink
RUN wget https://archive.apache.org/dist/flink/flink-1.9.1/flink-1.9.1-bin-scala_2.11.tgz && \
    tar -xzvf flink-1.9.1-bin-scala_2.11.tgz && \
    mv flink-1.9.1 /usr/local/flink
ADD packages/flink-hadoop-uber.jar /usr/local/flink/lib/

# PATH
ENV PATH=/usr/local/flink/bin:/usr/local/spark/bin:/usr/local/hive/bin:/usr/local/kafka/bin:/usr/local/hadoop/bin/:/usr/local/hadoop/sbin:$PATH
RUN echo "PATH=/usr/local/flink/bin:/usr/local/spark/bin:/usr/local/hive/bin:/usr/local/kafka/bin:/usr/local/hadoop/bin/:/usr/local/hadoop/sbin:$PATH" >> /etc/environment

# involved scripts
ADD scripts/* /run/

WORKDIR /

CMD ["bash", "-c", "/run/entrypoint.sh && /run/wait_to_die.sh"]
