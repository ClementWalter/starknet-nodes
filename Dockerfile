FROM eqlabs/pathfinder:v0.3.5

USER root
RUN apt-get update && apt-get install -y curl
USER 1000:1000
