FROM razaqq/arch-base-armhf:latest
LABEL maintainer="github.com/razaqq"

# additional files
##################

# add install bash script
ADD build/root/*.sh /root/

# add bash script to run openvpn
ADD run/root/*.sh /root/

# add bash script to run privoxy
ADD run/nobody/*.sh /home/nobody/

# install app
#############

RUN ["docker-build-start"]

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh /home/nobody/*.sh && \
	/bin/bash /root/install.sh

RUN ["docker-build-end"]

# docker settings
#################

# expose port for privoxy
EXPOSE 8118
