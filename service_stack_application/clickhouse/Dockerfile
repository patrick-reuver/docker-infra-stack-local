ARG CLICKHOUSE_BASE_IMAGE=clickhouse/clickhouse-server:24.8
FROM ${CLICKHOUSE_BASE_IMAGE}

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install -y --no-install-recommends curl jq \
  && rm -rf /var/lib/apt/lists/*

COPY ../../scripts/infisical-runtime-env.sh /usr/local/bin/infisical-runtime-env.sh
RUN chmod 0755 /usr/local/bin/infisical-runtime-env.sh
