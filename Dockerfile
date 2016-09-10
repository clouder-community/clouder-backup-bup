FROM clouder/clouder-base
MAINTAINER Yannick Buron yburon@goclouder.net

RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get -y -q install supervisor python2.7-dev python-fuse python-pyxattr python-pylibacl python-tornado linux-libc-dev acl attr par2 git make cron ncftp g++ 

ADD http://www.claudiokuenzler.com/downloads/nrpe/nagios-nrpe-server_2.15-1ubuntu2_amd64.xenial.deb /tmp/nrpe.deb
RUN dpkg -i /tmp/nrpe.deb

RUN git clone git://github.com/bup/bup /opt/bup
RUN make -C /opt/bup
RUN make install -C /opt/bup

RUN mkdir  /home/backup
RUN chown -R backup:backup /home/backup
RUN usermod -d /home/backup -s /bin/bash backup
RUN mkdir /opt/backup
RUN chown -R backup:backup /opt/backup
RUN chmod -R 700 /opt/backup

USER backup
RUN mkdir  /home/backup/.ssh
RUN mkdir  /home/backup/.ssh/keys
RUN ln -s /opt/keys/authorized_keys /home/backup/.ssh/authorized_keys
RUN chmod -R 700 /home/backup/.ssh
RUN touch /home/backup/.hushlogin
RUN mkdir /opt/backup/bup

ENV BUP_DIR /opt/backup/bup
RUN bup init


USER root

ADD sources/check_backup /opt/check_backup
RUN chmod +x /opt/check_backup
RUN sed -i "s/nrpe_user=nagios/nrpe_user=backup/g" /etc/nagios/nrpe.cfg
RUN sed -i "s/nrpe_group=nagios/nrpe_group=backup/g" /etc/nagios/nrpe.cfg
RUN sed -i "s/allowed_hosts=127.0.0.1/allowed_hosts=172.17.0.0\/16/g" /etc/nagios/nrpe.cfg
RUN sed -i "s/dont_blame_nrpe=0/dont_blame_nrpe=1/g" /etc/nagios/nrpe.cfg
RUN echo "command[check_backup]=/opt/check_backup \$ARG1\$ \$ARG2\$ \$ARG3\$ \$ARG4\$" >> /etc/nagios/nrpe.cfg

RUN echo "[supervisord]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf

RUN echo "[program:cron]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=cron -f" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf

RUN echo "[program:bup-web]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=su backup -c 'BUP_DIR=/opt/backup/bup bup web :8080'" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf

RUN echo "[program:nrpe]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=/etc/init.d/nagios-nrpe-server restart" >> /etc/supervisor/conf.d/supervisord.conf

RUN echo "* * * * * root supervisorctl restart bup-web" >> /etc/crontab

CMD ["/usr/bin/supervisord"]
