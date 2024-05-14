FROM mydumper/mydumper:latest
LABEL authors="zqh"

WORKDIR ~/

COPY entrypoint.sh ~/entrypoint.sh
ENTRYPOINT ["/bin/bash", "~/entrypoint.sh"]
