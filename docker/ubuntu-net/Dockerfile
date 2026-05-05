FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    iproute2 \
    iputils-ping \
    net-tools \
    tcpdump \
    curl \
    dnsutils \
    traceroute \
    mtr \
    vim \
    nano \
    && apt clean

CMD ["/bin/bash"]
