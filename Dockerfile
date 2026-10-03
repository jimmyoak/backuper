FROM alpine:3.20

RUN apk add --no-cache bash openssh-client rsync gzip tzdata

COPY scripts/ /opt/backuper/

RUN find /opt/backuper -name "*.sh" -exec chmod +x {} \;

ENTRYPOINT ["/opt/backuper/entrypoint.sh"]
