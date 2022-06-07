FROM registry.access.redhat.com/ubi8/ubi
RUN mkdir /user1 && chmod 777 /user1 && mkdir /user1/artifacts && chmod 777 /user1/artifacts
WORKDIR /user1
ENV HOME=/user1

COPY oc /usr/local/bin/oc 
COPY jq /usr/local/bin/jq
COPY cloudctl-linux-amd64-v3.2.3-1557 /usr/local/bin/cloudctl
COPY es-plugin /user1/es-plugin
COPY apic-slim /usr/local/bin/apic
ADD *.sh .
ADD template* .
ADD *.yaml .

RUN chmod a+x /usr/local/bin/* && chmod a+x /user1/*.sh && mkdir .kube && mkdir .cloudctl && chmod 777 .*

CMD /usr/bin/env bash


