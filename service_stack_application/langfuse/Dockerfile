ARG LANGFUSE_BASE_IMAGE=langfuse/langfuse:3
FROM ${LANGFUSE_BASE_IMAGE}

USER root

RUN apk add --no-cache curl jq

COPY ../../scripts/infisical-runtime-env.sh /usr/local/bin/infisical-runtime-env.sh
RUN chmod 0755 /usr/local/bin/infisical-runtime-env.sh
