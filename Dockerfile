
FROM postgres:14-alpine AS pgtap
ENV PGTAP_VERSION v1.2.0
RUN apk -U add \
    alpine-sdk \
    perl \
 && git clone https://github.com/theory/pgtap \
 && cd pgtap \
 && git checkout ${PGTAP_VERSION} \
 && make \
 && make install
FROM postgres:14-alpine AS pgtapfinal
COPY --from=pgtap /usr/local/share/postgresql/extension/pgtap* /usr/local/share/postgresql/extension/
RUN apk -U add \
    build-base \
    perl-dev \
 && cpan TAP::Parser::SourceHandler::pgTAP \
 && apk del -r build-base
RUN mkdir -p /opt/pgtests
COPY ./database/t/ /opt/pgtests

FROM ubuntu:rolling AS mastro-manucci
ENV OS_LOCALE="en_US.UTF-8"
RUN apt-get update && apt-get upgrade -y
RUN apt-get -y install perl cpanminus libmojolicious-perl libmojo-pg-perl libjson-xs-perl liblwp-protocol-https-perl \
    libmojolicious-plugin-openapi-perl libdigest-sha-perl libemail-valid-perl libcrypt-jwt-perl libdata-uuid-perl \
    libmojolicious-plugin-oauth2-perl libcrypt-openssl-bignum-perl libcrypt-openssl-rsa-perl libmojo-jwt-perl \
    libnumber-format-perl libdatetime-perl
RUN mkdir -p /var/www/app
COPY ./cpanfile /var/www/app
COPY ./src/ /var/www/app/
WORKDIR /var/www/app
RUN cpanm --installdeps .

# for /build endpoint. Use --build-arg to set these properly
ARG BUILD_VERSION=${BUILD_VERSION:-buildversion}
ENV BUILD_VERSION $BUILD_VERSION
ARG BUILD_REVISION=${BUILD_REVISION:-buildrevision}
ENV BUILD_REVISION $BUILD_REVISION
ARG BUILD_TIMESTAMP=${BUILD_TIMESTAMP:-buildtimestamp}
ENV BUILD_TIMESTAMP $BUILD_TIMESTAMP
ARG BUILD_PROJECT=${BUILD_PROJECT:-buildproject}
ENV BUILD_PROJECT $BUILD_PROJECT

EXPOSE 3000
CMD ./script/mastro_manucci prefork -m production -w 20 -c 10 -l http://*:3000



