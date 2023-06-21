
From mariadb:10.11.3

RUN apt-get update && apt-get -y install cron openssh-client

COPY backup_mysql_cron.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/backup_mysql_cron.sh
COPY docker-entrypoint_with_cron.sh /usr/local/bin
RUN chmod 0755 /usr/local/bin/docker-entrypoint_with_cron.sh

RUN mkdir -p /home/mysql
RUN chown mysql /home/mysql

ENTRYPOINT ["docker-entrypoint_with_cron.sh"]

EXPOSE 3306
CMD ["mariadbd"]
