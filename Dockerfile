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

# Avoid interactive questions when installing Kerberos
ENV DEBIAN_FRONTEND=noninteractive

# Copy cmake and OpenDNP3 from the build stage
COPY --from=build /tmp_cmake /
COPY --from=build /tmp_dnp3 /
# Install Python plugins
COPY ./python /usr/local/foglamp/python/
# Copy foglamp startup script
COPY foglamp.sh /usr/local/foglamp/foglamp.sh


RUN apt update && apt upgrade -y && apt install wget rsyslog python3 python3-pip build-essential libssl-dev python-dev python3-dev git nano sed iputils-ping inetutils-telnet -y && \
    wget --no-check-certificate https://foglamp.s3.amazonaws.com/1.8.1/ubuntu1804/x86_64/foglamp-1.8.1_x86_64_ubuntu1804.tgz && \
    tar -xzvf foglamp-1.8.1_x86_64_ubuntu1804.tgz && \
    # Install any dependenies for the .deb file
    apt -y install `dpkg -I ./foglamp/1.8.1/ubuntu1804/x86_64/foglamp-1.8.1-x86_64.deb | awk '/Depends:/{print$2}' | sed 's/,/ /g'` && \
    dpkg-deb -R ./foglamp/1.8.1/ubuntu1804/x86_64/foglamp-1.8.1-x86_64.deb foglamp-1.8.1-x86_64 && \
    cp -r foglamp-1.8.1-x86_64/usr /.  && \
    mv /usr/local/foglamp/data.new /usr/local/foglamp/data && \
    # Install plugins
    # Comment out any packages that you don't need to make the image smaller
    mkdir /package_temp && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-asset-1.8.1-x86_64.deb /package_temp/foglamp-filter-asset-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-blocktest-1.8.1-x86_64.deb /package_temp/foglamp-filter-blocktest-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-change-1.8.1-x86_64.deb /package_temp/foglamp-filter-change-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-delta-1.8.1-x86_64.deb /package_temp/foglamp-filter-delta-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-downsample-1.8.1-x86_64.deb /package_temp/foglamp-filter-downsample-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-ema-1.8.1-x86_64.deb /package_temp/foglamp-filter-ema-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-eventrate-1.8.1-x86_64.deb /package_temp/foglamp-filter-eventrate-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-expression-1.8.1-x86_64.deb /package_temp/foglamp-filter-expression-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-fft-1.8.1-x86_64.deb /package_temp/foglamp-filter-fft-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-fft2-1.8.1-x86_64.deb /package_temp/foglamp-filter-fft2-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-flirvalidity-1.8.1-x86_64.deb /package_temp/foglamp-filter-flirvalidity-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-metadata-1.8.1-x86_64.deb /package_temp/foglamp-filter-metadata-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-python27-1.8.1-x86_64.deb /package_temp/foglamp-filter-python27-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-python35-1.8.1-x86_64.deb /package_temp/foglamp-filter-python35-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-rate-1.8.1-x86_64.deb /package_temp/foglamp-filter-rate-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-rms-1.8.1-x86_64.deb /package_temp/foglamp-filter-rms-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-rms-trigger-1.8.1-x86_64.deb /package_temp/foglamp-filter-rms-trigger-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-scale-1.8.1-x86_64.deb /package_temp/foglamp-filter-scale-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-scale-set-1.8.1-x86_64.deb /package_temp/foglamp-filter-scale-set-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-simple-python-1.8.1-x86_64.deb /package_temp/foglamp-filter-simple-python-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-statistics-1.8.1-x86_64.deb /package_temp/foglamp-filter-statistics-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-threshold-1.8.1-x86_64.deb /package_temp/foglamp-filter-threshold-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-filter-vibration-features-1.8.1-x86_64.deb /package_temp/foglamp-filter-vibration-features-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-gcp-1.8.1-x86_64.deb /package_temp/foglamp-north-gcp-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-harperdb-1.8.1-x86_64.deb /package_temp/foglamp-north-harperdb-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-http-north-1.8.1-x86_64.deb /package_temp/foglamp-north-http-north-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-httpc-1.8.1-x86_64.deb /package_temp/foglamp-north-httpc-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-influxdb-1.8.1-x86_64.deb /package_temp/foglamp-north-influxdb-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-influxdbcloud-1.8.1-x86_64.deb /package_temp/foglamp-north-influxdbcloud-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-kafka-1.8.1-x86_64.deb /package_temp/foglamp-north-kafka-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-kafka-python-1.8.1-x86_64.deb /package_temp/foglamp-north-kafka-python-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-opcua-1.8.1-x86_64.deb /package_temp/foglamp-north-opcua-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-splunk-1.8.1-x86_64.deb /package_temp/foglamp-north-splunk-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-north-thingspeak-1.8.1-x86_64.deb /package_temp/foglamp-north-thingspeak-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-alexa-1.8.1-x86_64.deb /package_temp/foglamp-notify-alexa-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-asset-1.8.1-x86_64.deb /package_temp/foglamp-notify-asset-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-blynk-1.8.1-x86_64.deb /package_temp/foglamp-notify-blynk-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-email-1.8.1-x86_64.deb /package_temp/foglamp-notify-email-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-hangouts-1.8.1-x86_64.deb /package_temp/foglamp-notify-hangouts-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-ifttt-1.8.1-x86_64.deb /package_temp/foglamp-notify-ifttt-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-jira-1.8.1-x86_64.deb /package_temp/foglamp-notify-jira-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-north-1.8.1-x86_64.deb /package_temp/foglamp-notify-north-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-python35-1.8.1-x86_64.deb /package_temp/foglamp-notify-python35-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-slack-1.8.1-x86_64.deb /package_temp/foglamp-notify-slack-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-notify-telegram-1.8.1-x86_64.deb /package_temp/foglamp-notify-telegram-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-rule-average-1.8.1-x86_64.deb /package_temp/foglamp-rule-average-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-rule-bad-bearing-1.8.1-x86_64.deb /package_temp/foglamp-rule-bad-bearing-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-rule-engine-failure-1.8.1-x86_64.deb /package_temp/foglamp-rule-engine-failure-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-rule-outofbound-1.8.1-x86_64.deb /package_temp/foglamp-rule-outofbound-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-rule-periodic-1.8.1-x86_64.deb /package_temp/foglamp-rule-periodic-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-rule-simple-expression-1.8.1-x86_64.deb /package_temp/foglamp-rule-simple-expression-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-service-notification-1.8.1-x86_64.deb /package_temp/foglamp-service-notification-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-beckhoff-1.8.1-x86_64.deb /package_temp/foglamp-south-beckhoff-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-benchmark-1.8.1-x86_64.deb /package_temp/foglamp-south-benchmark-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-cc2650-1.8.1-x86_64.deb /package_temp/foglamp-south-cc2650-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-coap-1.8.1-x86_64.deb /package_temp/foglamp-south-coap-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-csv-1.8.1-x86_64.deb /package_temp/foglamp-south-csv-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-CSV-Async-1.8.1-x86_64.deb /package_temp/foglamp-south-CSV-Async-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-csvplayback-1.8.1-x86_64.deb /package_temp/foglamp-south-csvplayback-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-digiducer-1.8.1-x86_64.deb /package_temp/foglamp-south-digiducer-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-dnp3-1.8.1-x86_64.deb /package_temp/foglamp-south-dnp3-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-expression-1.8.1-x86_64.deb /package_temp/foglamp-south-expression-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-flirax8-1.8.1-x86_64.deb /package_temp/foglamp-south-flirax8-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-http-south-1.8.1-x86_64.deb /package_temp/foglamp-south-http-south-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-modbus-1.8.1-x86_64.deb /package_temp/foglamp-south-modbus-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-modbustcp-1.8.1-x86_64.deb /package_temp/foglamp-south-modbustcp-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-mqtt-sparkplug-1.8.1-x86_64.deb /package_temp/foglamp-south-mqtt-sparkplug-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-opcua-1.8.1-x86_64.deb /package_temp/foglamp-south-opcua-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-openweathermap-1.8.1-x86_64.deb /package_temp/foglamp-south-openweathermap-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-person-detection-1.8.1-x86_64.deb /package_temp/foglamp-south-person-detection-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-phidget-1.8.1-x86_64.deb /package_temp/foglamp-south-phidget-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-playback-1.8.1-x86_64.deb /package_temp/foglamp-south-playback-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-random-1.8.1-x86_64.deb /package_temp/foglamp-south-random-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-randomwalk-1.8.1-x86_64.deb /package_temp/foglamp-south-randomwalk-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-roxtec-1.8.1-x86_64.deb /package_temp//foglamp-south-roxtec-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-s7-1.8.1-x86_64.deb /package_temp/foglamp-south-s7-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-sarcos-1.8.1-x86_64.deb /package_temp/foglamp-south-sarcos-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-sensorphone-1.8.1-x86_64.deb /package_temp/foglamp-south-sensorphone-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-sinusoid-1.8.1-x86_64.deb /package_temp/foglamp-south-sinusoid-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-systeminfo-1.8.1-x86_64.deb /package_temp/foglamp-south-systeminfo-1.8.1-x86_64/ && \
    dpkg-deb -R /foglamp/1.8.1/ubuntu1804/x86_64/foglamp-south-wind-turbine-1.8.1-x86_64.deb /package_temp/foglamp-south-wind-turbine-1.8.1-x86_64/ && \
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
    python3 setup.py install && \ 
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
      version="1.8.1" \
      description="FogLAMP IIoT Framework with pydnp3 running in Docker - Development and Debug tools - Installed from .deb packages"