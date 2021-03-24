##################
# Build image
##################
FROM ubuntu:18.04 as build

# Install CMAKE required to build OpenDNP3
RUN apt update && apt upgrade -y  && apt install -y \
    build-essential \
    git \
    libssl-dev \
    wget
RUN wget https://github.com/Kitware/CMake/releases/download/v3.18.2/cmake-3.18.2.tar.gz
RUN tar xvzf cmake-3.18.2.tar.gz
RUN cd cmake-3.18.2
WORKDIR /cmake-3.18.2
RUN ./bootstrap
RUN make
# make install for next stage
RUN make DESTDIR=/tmp_cmake install
# make install for building opendnp3
RUN make install

# Build OpenDNP3 libraries required for pydnp3
WORKDIR /
RUN git clone https://github.com/dnp3/opendnp3.git
WORKDIR /opendnp3
RUN mkdir build
RUN cd build
WORKDIR /opendnp3/build
RUN pwd
RUN cmake ..
RUN make
RUN make DESTDIR=/tmp_dnp3 install

##################
# Deployment image
##################
FROM ubuntu:18.04

# FogLAMP version, ditribution, and platform
ENV FOGLAMP_VERSION=1.9.0
ENV FOGLAMP_DISTRIBUTION=ubuntu1804
ENV FOGLAMP_PLATFORM=x86_64

# Avoid interactive questions when installing Kerberos
ENV DEBIAN_FRONTEND=noninteractive

# Copy cmake and OpenDNP3 from the build stage
COPY --from=build /tmp_cmake /
COPY --from=build /tmp_dnp3 /

RUN apt update && apt install -y --no-install-recommends \
    #build-essential \
    #git \
    inetutils-telnet \
    iputils-ping \
    #libssl-dev \
    nano \
    #python-dev \
    #python3 \
    #python3-dev \
    #python3-pip \
    rsyslog \
    sed \
    wget && \
    # Download Foglamp package and isntall
    wget --no-check-certificate https://foglamp.s3.amazonaws.com/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz && \
    tar -xzvf foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz && \
    #
    # The postinstall script of the .deb package enables and starts the foglamp service. Since services are not supported in docker
    # containers, we must modify the postinstall script to remove these lines so that the package will install without errors.
    # We will manually unpack the file, use sed to remove the offending lines, and then run 'apt install -yf' to install the 
    # package and the dependancies. Once the package is successfully installed, all of the service and plugin package
    # will install normally.
    #
    # Unpack .deb package    
    dpkg --unpack ./foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
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
    /foglamp.postinst && \
    # Install plugins
    # Comment out any packages that you don't need to make the image smaller
    # Notification Service
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-service-notification-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    # Filter Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-asset-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-blocktest-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-change-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-delta-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-downsample-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-ema-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-eventrate-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-fft-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-fft2-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-flirvalidity-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-metadata-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-python27-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-python35-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rate-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rms-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rms-trigger-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-scale-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-scale-set-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-simple-python-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-statistics-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-threshold-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-vibration-features-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    # North Plugins
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-gcp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-harperdb-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-http-north-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-httpc-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-influxdb-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-influxdbcloud-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-kafka-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-opcua-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-splunk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-thingspeak-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # Notification Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-alexa-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-asset-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-blynk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-email-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-hangouts-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-ifttt-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-jira-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-north-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-python35-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-slack-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-telegram-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # Rule Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-average-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-bad-bearing-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-engine-failure-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-outofbound-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-periodic-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-simple-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb && \
    # South Plugins
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-benchmark-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-coap-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-csv-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-CSV-Async-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-csvplayback-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-dnp3-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-modbus-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-flirax8-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-http-south-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-modbustcp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-mqtt-sparkplug-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-opcua-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-openweathermap-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-playback-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-random-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-randomwalk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-s7-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-sarcos-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-sinusoid-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    apt install -y /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-systeminfo-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb  && \
    # Cleanup
    rm -f ./*.tgz && \ 
    # You may choose to leave the installation packages in the directory in case you need to troubleshoot
    rm -rf -r /foglamp && \
    # General cleanup after using apt
    apt autoremove -y && \
    apt clean -y  && \
    rm -rf /var/lib/apt/lists/


# Install Python plugins
COPY ./python /usr/local/foglamp/python/

RUN python3 -m pip install --upgrade -r /usr/local/foglamp/python/requirements-b100dnp3.txt && \
    python3 -m pip install --upgrade -r /usr/local/foglamp/python/requirements-kafka-python.txt && \
    python3 -m pip install --upgrade -r /usr/local/foglamp/python/requirements-apt_eclipse.txt && \
    python3 -m pip install --upgrade -r /usr/local/foglamp/python/requirements-vaisala_opt100.txt

# Copy foglamp startup script
COPY foglamp.sh /usr/local/foglamp/foglamp.sh

# Copy Kakfa certs to /etc/ssl/certs
COPY /etc/ssl/certs/jearootca.cer /etc/ssl/certs/jearootca.cer
COPY /etc/ssl/certs/testkafka.pem /etc/ssl/certs/testkafka.pem

ENV FOGLAMP_ROOT=/usr/local/foglamp

VOLUME /usr/local/foglamp/data

# foglamp API port for http and https, kerberos
EXPOSE 8081 1995 502 23

# start rsyslog, foglamp, and tail syslog
CMD ["bash","/usr/local/foglamp/foglamp.sh"]

LABEL maintainer="rob@raesemann.com" \
      author="Rob Raesemann" \
      target="Docker" \
      version="${FOGLAMP_VERSION}" \
      description="FogLAMP IIoT Framework with pydnp3 running in Docker - Development and Debug tools - Installed from .deb packages"