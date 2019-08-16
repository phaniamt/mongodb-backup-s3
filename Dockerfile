FROM mongo

# Install Python and Cron
RUN apt-get update && apt-get -y install awscli cron

ADD run.sh /run.sh
CMD /run.sh
