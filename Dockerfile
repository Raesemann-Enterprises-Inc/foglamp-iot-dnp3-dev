##################
# Build image
##################
FROM ubuntu:20.04 as build

ENV CMAKE_VERSION  3.27.4

# Install CMAKE required to build OpenDNP3
RUN apt update && apt upgrade -y  && apt install -y \
    build-essential \
    git \
    libssl-dev \
    wget
RUN wget https://github.com/Kitware/CMake/archive/refs/tags/v${CMAKE_VERSION}.tar.gz -O cmake.tar.gz &&\
    mkdir cmake &&\
    tar xvzf cmake.tar.gz --strip-components=1 -C cmake &&\
    cd cmake &&\
    ./bootstrap &&\
    make &&\
    # make install for next stage
    RUN make DESTDIR=/tmp_cmake install &&\
    # make install for building opendnp3
    make install

# Build OpenDNP3 libraries required for pydnp3
WORKDIR /
RUN git clone https://github.com/dnp3/opendnp3.git &&\
    cd /opendnp3 &&\
    mkdir build &&\
    cd build &&\
    pwd &&\
    cmake .. &&\
    make &&\
    make DESTDIR=/tmp_dnp3 install

##################
# Deployment image
##################
FROM ubuntu:20.04

# FogLAMP version, ditribution, and platform
ENV FOGLAMP_VERSION=2.1.0
ENV FOGLAMP_DISTRIBUTION=ubuntu2004
ENV FOGLAMP_PLATFORM=x86_64

# Avoid interactive questions when installing Kerberos
ENV DEBIAN_FRONTEND=noninteractive

# Copy cmake and OpenDNP3 from the build stage
COPY --from=build /tmp_cmake /
COPY --from=build /tmp_dnp3 /

RUN apt update && apt dist-upgrade -y && apt install -y --no-install-recommends \
    # development tools
    autoconf \
    automake \
    avahi-daemon \
    build-essential \
    ca-certificates \
    cmake \
    cpulimit \
    curl \
    g++ \
    git \
    krb5-user \
    libboost-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libpq-dev \
    libsqlite3-dev \
    libtool \
    libz-dev \
    make \
    pkg-config \
    postgresql \
    # for building pydnp3
    python2.7-dev \
    python3-dev \
    python3-pip \
    python3-setuptools \
    sqlite3 \
    uuid-dev \
    # tools to make troubleshooting easier from inside the container
    build-essential \
    gcc \
    dnsutils \
    inetutils-telnet \
    iproute2 \
    iputils-ping \
    jq \
    nano \
    openssh-client \
    # required packages
    rsyslog \
    sed \
    wget # && \
    # Download Foglamp package and install
RUN echo https://foglamp.s3.amazonaws.com/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz
RUN wget --no-check-certificate https://foglamp.s3.amazonaws.com/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz && \
    tar -xzvf foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz && \
    #
    # The postinstall script of the .deb package enables and starts the foglamp service. Since services are not supported in docker
    # containers, we must modify the postinstall script to remove these lines so that the package will install without errors.
    # We will manually unpack the file, use sed to remove the offending lines, and then run 'apt install -yf' to install the 
    # package and the dependancies. Once the package is successfully installed, all of the service and plugin package
    # will install normally.
    #
    # Unpack .deb package    
    dpkg --unpack ./foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    # Remove lines that enable and start the service. They call enable_FOGLAMP_service() and start_FOGLAMP_service()
    # Save to /foglamp.postinst. We'll run that after we install the dependencies.
    sed '/^.*_foglamp_service$/d' /var/lib/dpkg/info/foglamp.postinst > /foglamp.postinst && \
    # Rename the original file so that it doesn't get run in next step.
    mv /var/lib/dpkg/info/foglamp.postinst /var/lib/dpkg/info/foglamp.postinst.save && \
    # Configure the package and isntall dependencies.
    apt install -yf && \
    # Manually run the post install script - creates certificates, installs python dependencies etc.
    mkdir -p /usr/local/foglamp/data/extras/fogbench && \
    chmod +x /foglamp.postinst && \
    /foglamp.postinst
    # Install plugins
    # Comment out any packages that you don't need to make the image smaller
    # Notification Service
RUN apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-service-notification_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    # Filter Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-asset_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-blocktest_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-change_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-delta_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-downsample_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-ema_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-eventrate_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-expression_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-fft_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-fft2_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-flirvalidity_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-metadata_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-python27_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-python35_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rate_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rms_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rms-trigger_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-scale_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-scale-set_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-simple-python_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-statistics_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-threshold_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-vibration-features_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    # North Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-harperdb_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-http-north_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-httpc_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-influxdb_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-influxdbcloud_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-kafka_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-opcua_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    # Notification Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-alexa_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-asset_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-email_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-ifttt_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-north_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-python35_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-slack_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    # Rule Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-average_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-outofbound_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-periodic_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-simple-expression_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb && \
    # South Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-benchmark_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-coap_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-csv_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-CSV-Async_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-csvplayback_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-dnp3_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-expression_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-modbus_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-flirax8_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-http-south_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-modbustcp_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-mqtt-sparkplug_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-opcua_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-openweathermap_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-playback_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-random_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-randomwalk_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-s7_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-sinusoid_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-systeminfo_${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}.deb  && \
    # Cleanup
    rm -f ./*.tgz && \ 
    # You may choose to leave the installation packages in the directory in case you need to troubleshoot
    rm -rf -r /foglamp && \
    # General cleanup after using apt
    apt autoremove -y && \
    apt clean -y  && \
    rm -rf /var/lib/apt/lists/

# Install code-server 
ENV PATH /root/.local/bin:$PATH
ENV PASSWORD=Password123
RUN curl -fsSL https://code-server.dev/install.sh > install.sh && \
    sh install.sh --method=standalone && \
    rm -f install.sh && \
    code-server --install-extension ms-python.python && \
    code-server --install-extension ms-vscode.cpptools && \
    code-server --install-extension twxs.cmake && \
    code-server --install-extension alexcvzz.vscode-sqlite && \
    code-server --install-extension mechatroner.rainbow-csv && \
    # Install pylint for code-server
    pip3 install pylint
# copy .pylintrc configuration
COPY /root /root 


# Install JEA custom Python plugins
COPY ./python /usr/local/foglamp/python/

# Install dependencies from all of the requirements files in /usr/local/foglamp/python
RUN for i in /usr/local/foglamp/python/requirements*.txt; do python3 -m pip install --upgrade -r $i; done;

# Copy foglamp startup script
COPY foglamp.sh /usr/local/foglamp/foglamp.sh

# Copy Kakfa certs and resolv.conf to container
# COPY /etc /etc

ENV FOGLAMP_ROOT=/usr/local/foglamp

# Volume for development. This saves any changes you make to plugins during development.
VOLUME /usr/local/foglamp:rw

# Volume for production. This saves only the configuration and data.
# VOLUME /usr/local/foglamp/data

# code server (8080) and foglamp API port for http and https (8081 and 1995)
# OPC UA north 4840
EXPOSE 8080 8081 4840 1995 6683 6684

# start rsyslog, foglamp, and tail syslog
CMD ["bash","/usr/local/foglamp/foglamp.sh"]

LABEL maintainer="rob@raesemann.com" \
      author="Rob Raesemann" \
      target="Docker" \
      version="${FOGLAMP_VERSION}" \
      description="FogLAMP IIoT Framework with pydnp3 running in Docker - Development and Debug tools - Installed from .deb packages"