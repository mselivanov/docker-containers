FROM cloudera/quickstart:latest
RUN sudo rm -f /var/lib/rpm/__* 
RUN sudo rpm --rebuilddb -v -v
ADD docker-entrypoint.sh /docker-entrypoint.sh
CMD ["/docker-entrypoint.sh", "--express"]
