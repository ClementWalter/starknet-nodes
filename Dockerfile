FROM eqlabs/pathfinder:v0.4.0

USER root
RUN apt-get update && apt-get install -y curl
USER 1000:1000
