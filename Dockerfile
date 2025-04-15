FROM alpine:3.19

RUN apk add --no-cache bash coreutils openssl tar

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]

