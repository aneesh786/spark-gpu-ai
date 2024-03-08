ARG CUDA_VERSION=11.8.0
ARG spark_uid=185
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04

ARG PYSPARK_VERSION=3.3.1
ARG RAPIDS_VERSION=23.12.0
ARG ARCH=amd64
#ARG ARCH=arm64
# Install packages to build spark-rapids-ml
RUN apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y openjdk-8-jdk  tzdata \
    && rm -rf /var/lib/apt/lists

RUN apt-get update -y \
    && apt install -y git numactl python3.10-venv python3-pip python-is-python3 software-properties-common wget zip \
    && python -m pip install --upgrade pip \
    && rm -rf /var/lib/apt/lists

RUN apt-get update -y \
    && apt install -y python3.10-dev cmake curl vim \
    && rm -rf /var/lib/apt/lists

# install RAPIDS
# using ~= pulls in micro version patches
RUN pip install --no-cache-dir \
    cudf-cu11~=${RAPIDS_VERSION} \
    cuml-cu11~=${RAPIDS_VERSION} \
    --extra-index-url=https://pypi.nvidia.com

# install python dependencies
RUN pip install --no-cache-dir pyspark==${PYSPARK_VERSION} "scikit-learn>=1.2.1" \
    && pip install --no-cache-dir "black>=23.1.0" "build>=0.10.0" "isort>=5.12.0" "mypy>=1.0.0" \
    numpydoc findspark pydata-sphinx-theme pylint pytest "sphinx<6.0" "twine>=4.0.0"
RUN pip install -r https://raw.githubusercontent.com/NVIDIA/spark-rapids-ml/main/python/requirements.txt
RUN pip install spark_rapids_ml psutil pandas

RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN apt-get update
RUN apt-get install -y nvidia-container-toolkit

# Config JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0-openjdk-$ARCH

RUN set -ex && \
    ln -s /lib /lib64 && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/jars && \
    mkdir -p /opt/spark/examples && \
    mkdir -p /opt/spark/work-dir && \
    mkdir -p /opt/sparkRapidsPlugin && \
    mkdir -p /opt/sparkRapidsPlugin && \
    mkdir -p /etc/apk/ && \
    touch /etc/apk/repositories && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd
RUN apt-get update && \
    apt-get install -y python3.10 python3-pip && \
    apt-get install -y r-base r-base-dev && \
    rm -rf /var/lib/apt/lists/*

ENV SPARK_HOME /opt/spark
WORKDIR /opt/spark/work-dir

# Install required Python packages

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +rx /usr/bin/tini
COPY spark/jars /opt/spark/jars
COPY spark/bin /opt/spark/bin
COPY spark/sbin /opt/spark/sbin
COPY spark/kubernetes/dockerfiles/spark/entrypoint.sh /opt/
COPY spark/examples /opt/spark/examples
COPY spark/kubernetes/tests /opt/spark/tests
COPY spark/data /opt/spark/data
RUN chmod +rx /opt/entrypoint.sh

COPY rapids-4-spark_2.12-*.jar /opt/sparkRapidsPlugin
COPY getGpusResources.sh /opt/sparkRapidsPlugin
RUN chmod 777 /opt/sparkRapidsPlugin/getGpusResources.sh

### END OF CACHE ###

#ARG RAPIDS_ML_VER=main
#RUN git clone -b branch-$RAPIDS_ML_VER https://github.com/NVIDIA/spark-rapids-ml.git
#COPY . /spark-rapids-ml
#WORKDIR /spark-rapids-ml/python

# install spark-rapids-ml with requirements_dev.txt (in case it has diverged from cache)
#RUN pip install --no-cache-dir -r requirements_dev.txt \
#    && pip install --no-cache-dir -e .

#SHELL ["/bin/bash", "-c"]
ENTRYPOINT [ "/opt/entrypoint.sh" ]
# Specify the User that the actual main process will run as
#USER root
RUN useradd -m -u 185 -s /bin/bash spark
#WORKDIR /opt/spark
RUN chown -R spark:spark /opt/spark /opt/sparkRapidsPlugin /etc/apk /home/spark
RUN chown -R spark:spark /opt/spark/work-dir
RUN chmod -R 777 /opt/spark/work-dir
RUN usermod -aG sudo spark
