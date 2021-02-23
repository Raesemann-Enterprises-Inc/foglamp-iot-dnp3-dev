##################
# Build image
##################
FROM ubuntu:18.04 as build

# Install CMAKE required to build OpenDNP3
RUN apt update && apt upgrade -y  && apt install wget build-essential libssl-dev git -y
RUN wget --quiet https://github.com/Kitware/CMake/releases/download/v3.18.2/cmake-3.18.2.tar.gz
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
ENV FOGLAMP_VERSION=1.8.2
ENV FOGLAMP_DISTRIBUTION=ubuntu1804
ENV FOGLAMP_PLATFORM=x86_64

# Avoid interactive questions when installing Kerberos
ENV DEBIAN_FRONTEND=noninteractive

# Copy cmake and OpenDNP3 from the build stage
COPY --from=build /tmp_cmake /
COPY --from=build /tmp_dnp3 /
# Install Python plugins
COPY ./python /usr/local/foglamp/python/
# Copy foglamp startup script
COPY foglamp.sh /usr/local/foglamp/foglamp.sh

RUN apt update && apt install wget rsyslog python3 python3-pip build-essential libssl-dev python-dev python3-dev git nano sed iputils-ping inetutils-telnet -y && \
    wget --no-check-certificate https://foglamp.s3.amazonaws.com/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz && \
    tar -xzvf foglamp-${FOGLAMP_VERSION}_${FOGLAMP_PLATFORM}_${FOGLAMP_DISTRIBUTION}.tgz && \
    # Install any dependenies for the .deb file
    apt -y install `dpkg -I ./foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb | awk '/Depends:/{print$2}' | sed 's/,/ /g'` && \
    dpkg-deb -R ./foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb foglamp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM} && \
    cp -r foglamp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/usr /.  && \
    mv /usr/local/foglamp/data.new /usr/local/foglamp/data && \
    # Install plugins
    # Comment out any packages that you don't need to make the image smaller
    mkdir /package_temp && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-asset-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-asset-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-blocktest-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-blocktest-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-change-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-change-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-delta-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-delta-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-downsample-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-downsample-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-ema-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-ema-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-eventrate-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-eventrate-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-fft-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-fft-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-fft2-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-fft2-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-flirvalidity-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-flirvalidity-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-metadata-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-metadata-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-python27-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-python27-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-python35-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-python35-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rate-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-rate-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rms-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-rms-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-rms-trigger-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-rms-trigger-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-scale-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-scale-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-scale-set-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-scale-set-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-simple-python-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-simple-python-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-statistics-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-statistics-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-threshold-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-threshold-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-filter-vibration-features-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-filter-vibration-features-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-gcp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-gcp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-harperdb-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-harperdb-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-http-north-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-http-north-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-httpc-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-httpc-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-influxdb-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-influxdb-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-influxdbcloud-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-influxdbcloud-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-kafka-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-kafka-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-opcua-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-opcua-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-splunk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-splunk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-north-thingspeak-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-north-thingspeak-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-alexa-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-alexa-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-asset-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-asset-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-blynk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-blynk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-email-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-email-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-hangouts-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-hangouts-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-ifttt-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-ifttt-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-jira-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-jira-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-north-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-north-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-python35-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-python35-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-slack-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-slack-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-notify-telegram-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-notify-telegram-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-average-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-rule-average-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-bad-bearing-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-rule-bad-bearing-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-engine-failure-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-rule-engine-failure-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-outofbound-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-rule-outofbound-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-periodic-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-rule-periodic-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-rule-simple-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-rule-simple-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-service-notification-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-service-notification-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-benchmark-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-benchmark-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-coap-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-coap-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-csv-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-csv-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-CSV-Async-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-CSV-Async-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-csvplayback-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-csvplayback-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-dnp3-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-dnp3-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-expression-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-flirax8-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-flirax8-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-http-south-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-http-south-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-modbus-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-modbus-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-modbustcp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-modbustcp-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-mqtt-sparkplug-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-mqtt-sparkplug-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-opcua-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-opcua-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-openweathermap-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-openweathermap-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-playback-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-playback-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-random-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-random-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-randomwalk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-randomwalk-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-s7-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-s7-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-sarcos-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-sarcos-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-sinusoid-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-sinusoid-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    dpkg-deb -R /foglamp/${FOGLAMP_VERSION}/${FOGLAMP_DISTRIBUTION}/${FOGLAMP_PLATFORM}/foglamp-south-systeminfo-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}.deb /package_temp/foglamp-south-systeminfo-${FOGLAMP_VERSION}-${FOGLAMP_PLATFORM}/ && \
    # Copy plugins into place
    cp -r /package_temp/*/usr /.  && \
    # install required python packages
    python3 -m pip install pip --upgrade && \
    pip install opencv-python && \
    for file in /usr/local/foglamp/python/requirements*.txt; do pip3 install -r "$file"; done && \
    for file in /usr/local/foglamp/python/extras_install*.sh; do ./"$file"; done && \
    # Install the patched version of pybindll that allows pydnp3 install
    git clone https://github.com/ChargePoint/pybind11.git && \
    cd /pybind11 && \
    # python3 setup.py install && \ 
    cd / && \
    rm -r /pybind11 && \
    cd /usr/local/foglamp && \
    ./scripts/certificates foglamp 365 && \
    chown -R root:root /usr/local/foglamp && \
    chown -R ${SUDO_USER}:${SUDO_USER} /usr/local/foglamp/data && \ 
    # Cleanup
    rm -f ./*.tgz && \ 
    rm -rf ./package_temp && \ 
    rm -rf -r ./foglamp

ENV foglamp_ROOT=/usr/local/foglamp

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