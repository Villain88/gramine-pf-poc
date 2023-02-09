FROM ubuntu:22.04

RUN mkdir -p /poc/run /poc/data
RUN apt update \
    && apt install -y libnss-mdns libnss-myhostname lsb-release \
    && apt install -y python3.10 python3-pip libcurl4

ENTRYPOINT ["/usr/bin/python3.10", "/poc/run/entrypoint.py"]
