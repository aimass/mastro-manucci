
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

FROM perl
ENV OS_LOCALE="en_US.UTF-8"
RUN mkdir -p /var/www/app
COPY ./cpanfile /var/www/app
COPY ./src/ /var/www/app/
WORKDIR /var/www/app
RUN cpanm --installdeps .
EXPOSE 9230
EXPOSE 9240
CMD ./script/mastro_manucci prefork -m production http://*:9230
#CMD ./script/moonshot_worker prefork -m production http://*:9240



