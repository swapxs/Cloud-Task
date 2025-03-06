FROM postgres:9.4

ENV POSTGRES_DB=notejam
ENV POSTGRES_USER=notejam_user
ENV POSTGRES_PASSWORD=password

COPY init.sql /docker-entrypoint-initdb.d/
