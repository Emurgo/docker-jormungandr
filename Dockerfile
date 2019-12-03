ARG JORMUNGANDR_VERSION=0.7.5
ARG JORMUNGANDR_COMMIT=v0.7.5

FROM emurgornd/jormungandr:src-${JORMUNGANDR_COMMIT} AS src
FROM emurgornd/jormungandr:src-build-${JORMUNGANDR_COMMIT} AS src-build

FROM ubuntu:bionic AS jormungandr
ENV JORMUNGANDR_VERSION ${JORMUNGANDR_VERSION}
ENV JORMUNGANDR_COMMIT ${JORMUNGANDR_COMMIT}
LABEL jormungandr.commit="${JORMUNGANDR_COMMIT}"
LABEL jormungandr.version="${JORMUNGANDR_VERSION}"

RUN mkdir -p /nonexistent /data && \
    chown nobody: /nonexistent /data
ENV HOME /nonexistent
VOLUME ["/data"]
WORKDIR /data
ENV DATA_DIR /data
ENV PUBLIC_PORT 8299
ENV JORMUNGANDR_RESTAPI_URL http://localhost:8443/api

RUN apt-get update -qq && \
    apt-get install -y git curl sudo net-tools iproute2 jq xxd

USER nobody
RUN curl -sSL https://raw.githubusercontent.com/rcmorano/baids/master/baids | bash -s install && \
    echo source ~/.baids/baids > ~/.bashrc && \
    curl -sLo ~/.baids/functions.d/10-bash-yaml https://raw.githubusercontent.com/jasperes/bash-yaml/master/script/yaml.sh && \
    git clone https://github.com/rcmorano/baids-jormungandr.git ~/.baids/functions.d/jormungandr

COPY --from=src-build /output/ /usr/local/bin/
COPY --from=src /src /src
RUN jcli auto-completion bash ${HOME}/.baids/functions.d

USER root
COPY ./assets/bin/entrypoint /usr/local/bin/entrypoint
ENTRYPOINT ["/bin/bash", "-c", "chown -R nobody: /data; sudo -EHu nobody /usr/local/bin/entrypoint"]
