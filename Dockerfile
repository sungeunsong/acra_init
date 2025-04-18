FROM rockylinux:8

RUN dnf -y install \
    bash coreutils openssl tar && \
    dnf clean all

# 녹화 저장 경로 생성
RUN mkdir -p /opt/wax/server/audit

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
