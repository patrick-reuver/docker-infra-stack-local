ARG PRESIDIO_BASE_IMAGE=mcr.microsoft.com/presidio-analyzer:latest
FROM ${PRESIDIO_BASE_IMAGE}

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install -y --no-install-recommends jq \
  && rm -rf /var/lib/apt/lists/*

COPY ../../scripts/infisical-runtime-env.sh /usr/local/bin/infisical-runtime-env.sh
RUN chmod 0755 /usr/local/bin/infisical-runtime-env.sh

USER 1001
