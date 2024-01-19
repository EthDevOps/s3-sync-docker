FROM alpine:3
ARG ARCH=linux-amd64

EXPOSE 8081

# Install minio client
RUN echo "building for $ARCH"
RUN apk --no-cache add curl
RUN curl https://dl.min.io/client/mc/release/${ARCH}/mc --create-dirs -o /usr/bin/mc && \
  chmod +x /usr/bin/mc

COPY mirror-s3.sh /usr/bin
RUN chmod +x /usr/bin/mirror-s3.sh

ENTRYPOINT ["/usr/bin/mirror-s3.sh"]
