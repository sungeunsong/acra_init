FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    bash coreutils openssl tar \
    && apt-get clean

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
