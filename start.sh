#!/bin/bash

# strip whitespace from start and end of VPN_ENABLED env var
VPN_ENABLED=$(echo "${VPN_ENABLED}" | sed -e 's/^[ \t]*//')

# if vpn set to "no" then don't run openvpn
if [[ "${VPN_ENABLED}" == "no" ]]; then

	echo "[info] VPN not enabled, skipping configuration of OpenVPN"

else

	echo "[info] VPN is enabled, beginning configuration of OpenVPN"
	
	# create directory
	mkdir -p /config/openvpn
	
	# set rw for all users recursively in /config/openvpn
	chmod -R a+rw /config/openvpn/*
	
	# strip whitespace from start and end of all other env vars
	VPN_REMOTE=$(echo "${VPN_REMOTE}" | sed -e 's/^[ \t]*//')
	VPN_USER=$(echo "${VPN_USER}" | sed -e 's/^[ \t]*//')
	VPN_PASS=$(echo "${VPN_PASS}" | sed -e 's/^[ \t]*//')
	ENABLE_PRIVOXY=$(echo "${ENABLE_PRIVOXY}" | sed -e 's/^[ \t]*//')
	VPN_PORT=$(echo "${VPN_PORT}" | sed -e 's/^[ \t]*//')
	VPN_PROV=$(echo "${VPN_PROV}" | sed -e 's/^[ \t]*//')
	LAN_RANGE=$(echo"${LAN_RANGE}" | sed -e 's/^[ \t]*//')
	
	# wildcard search for openvpn config files
	VPN_CONFIG=$(find /config/openvpn -maxdepth 1 -name "*.ovpn" -print)

	# if vpn provider not set then exit
	if [[ -z "${VPN_PROV}" ]]; then
		echo "[crit] VPN provider not defined, please specify via env variable VPN_PROV" && exit 1

	# if airvpn vpn provider chosen then do NOT copy base config file
	elif [[ "${VPN_PROV}" == "airvpn" ]]; then

		echo "[info] VPN provider defined as ${VPN_PROV}"

		if [[ -z "${VPN_CONFIG}" ]]; then
			echo "[crit] Missing OpenVPN configuration file in /config/openvpn/ (no files with an ovpn extension exist) please create and restart delugevpn" && exit 1
		fi
		
		# convert CRLF (windows) to LF (unix)
		tr -d '\r' < "${VPN_CONFIG}" > /tmp/convert.ovpn && mv /tmp/convert.ovpn "${VPN_CONFIG}"
		
	# if pia vpn provider chosen then copy base config file and pia certs
	elif [[ "${VPN_PROV}" == "pia" ]]; then

		echo "[info] VPN provider defined as ${VPN_PROV}"

		# copy default certs
		cp -f /home/nobody/ca.crt /config/openvpn/ca.crt
		cp -f /home/nobody/crl.pem /config/openvpn/crl.pem

		# if no ovpn files exist then copy base file
		if [[ -z "${VPN_CONFIG}" ]]; then
			cp -f "/home/nobody/openvpn.ovpn" "/config/openvpn/openvpn.ovpn"
			VPN_CONFIG="/config/openvpn/openvpn.ovpn"
		fi

		# convert CRLF (windows) to LF (unix)
		tr -d '\r' < "${VPN_CONFIG}" > /tmp/convert.ovpn && mv /tmp/convert.ovpn "${VPN_CONFIG}"

		# if no remote gateway or port specified then use netherlands and default port
		if [[ -z "${VPN_REMOTE}" && -z "${VPN_PORT}" ]]; then
			echo "[warn] VPN remote gateway and port not defined, defaulting to netherlands port 1194"
			sed -i -e "s/remote\s.*/remote nl.privateinternetaccess.com 1194/g" "${VPN_CONFIG}"

		# if no remote gateway but port defined then use netherlands and defined port
		elif [[ -z "${VPN_REMOTE}" && ! -z "${VPN_PORT}" ]]; then
			echo "[warn] VPN remote gateway not defined and port defined, defaulting to netherlands"
			sed -i -e "s/remote\s.*/remote nl.privateinternetaccess.com ${VPN_PORT}/g" "${VPN_CONFIG}"

		# if remote gateway defined but port not defined then use default port
		elif [[ ! -z "${VPN_REMOTE}" && -z "${VPN_PORT}" ]]; then
			echo "[warn] VPN remote gateway defined but no port defined, defaulting to port 1194"
			sed -i -e "s/remote\s.*/remote ${VPN_REMOTE} 1194/g" "${VPN_CONFIG}"

		# if remote gateway and port defined then use both
		else
			echo "[info] VPN provider remote gateway and port defined as ${VPN_REMOTE} ${VPN_PORT}"
			sed -i -e "s/remote\s.*/remote ${VPN_REMOTE} ${VPN_PORT}/g" "${VPN_CONFIG}"
		fi

		# store credentials in separate file for authentication
		if ! $(grep -Fq "auth-user-pass credentials.conf" "${VPN_CONFIG}"); then
			sed -i -e 's/auth-user-pass.*/auth-user-pass credentials.conf/g' "${VPN_CONFIG}"
		fi

		# write vpn username to file
		if [[ -z "${VPN_USER}" ]]; then
			echo "[crit] VPN username not specified, please specify using env variable VPN_USER" && exit 1
		else
			echo "${VPN_USER}" > /config/openvpn/credentials.conf
		fi

		# append vpn password to file
		if [[ -z "${VPN_PASS}" ]]; then
			echo "[crit] VPN password not specified, please specify using env variable VPN_PASS" && exit 1
		else
			echo "${VPN_PASS}" >> /config/openvpn/credentials.conf
		fi

	# if custom vpn provider chosen then do NOT copy base config file
	elif [[ "${VPN_PROV}" == "custom" ]]; then

		echo "[info] VPN provider defined as ${VPN_PROV}"

		if [[ -z "${VPN_CONFIG}" ]]; then
			echo "[crit] Missing OpenVPN configuration file in /config/openvpn/ (no files with an ovpn extension exist) please create and restart delugevpn" && exit 1
		fi

		# convert CRLF (windows) to LF (unix)
		tr -d '\r' < "${VPN_CONFIG}" > /tmp/convert.ovpn && mv /tmp/convert.ovpn "${VPN_CONFIG}"

		# store credentials in separate file for authentication
		if ! $(grep -Fq "auth-user-pass credentials.conf" "${VPN_CONFIG}"); then
			sed -i -e 's/auth-user-pass.*/auth-user-pass credentials.conf/g' "${VPN_CONFIG}"
		fi

		# write vpn username to file
		if [[ -z "${VPN_USER}" ]]; then
			echo "[crit] VPN username not specified, please specify using env variable VPN_USER" && exit 1
		else
			echo "${VPN_USER}" > /config/openvpn/credentials.conf
		fi

		# append vpn password to file
		if [[ -z "${VPN_PASS}" ]]; then
			echo "[crit] VPN password not specified, please specify using env variable VPN_PASS" && exit 1
		else
			echo "${VPN_PASS}" >> /config/openvpn/credentials.conf
		fi

	# if provider none of the above then exit
	else
		echo "[crit] VPN provider ${VPN_PROV} not recognised, please specify airvpn, pia, or custom using env variable VPN_PROV" && exit 1
	fi

	# remove ping and ping-restart from ovpn file if present, now using flag --keepalive
	if $(grep -Fq "ping" "${VPN_CONFIG}"); then
		sed -i '/ping.*/d' "${VPN_CONFIG}"
	fi

	# remove persist-tun from ovpn file if present, this allows reconnection to tunnel on disconnect
	if $(grep -Fq "persist-tun" "${VPN_CONFIG}"); then
		sed -i '/persist-tun/d' "${VPN_CONFIG}"
	fi

	# read port number and protocol from ovpn file (used to define iptables rule)
	VPN_REMOTE=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=remote\s)[^\s]+')
	VPN_PORT=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=remote\s).*$' | grep -P -o -m 1 '(?<=\s)[\d]{2,5}(?=[\s])|[\d]{2,5}$')
	VPN_PROTOCOL=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=remote\s).*$' | grep -P -o -m 1 'udp|tcp')
	
	# if vpn protocol not defined for remote line then assume defined using proto line
	if [[ -z "${VPN_PROTOCOL}" ]]; then
		VPN_PROTOCOL=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=proto\s).*$' | grep -P -o -m 1 'udp|tcp')
	fi
	
	# check vpn remote host is defined
	if [[ -z "${VPN_REMOTE}" ]]; then
		echo "[crit] VPN provider remote gateway not found in ovpn file, please check ovpn file for remote gateway" && exit 1
	else
		echo "[info] VPN provider remote gateway from ovpn file is $VPN_REMOTE"
	fi

	# check vpn port is defined
	if [[ -z "${VPN_PORT}" ]]; then
		echo "[crit] VPN provider port not found in ovpn file, please check ovpn file for port number of gateway" && exit 1
	else
		echo "[info] VPN provider port number from ovpn file is $VPN_PORT"
	fi

	# check vpn protocol is defined
	if [[ -z "${VPN_PROTOCOL}" ]]; then
		echo "[crit] VPN provider protocol not found in ovpn file, please check ovpn file for protocol" && exit 1
	else
		echo "[info] VPN provider protocol from ovpn file is $VPN_PROTOCOL"
	fi	

	# set permissions to user nobody
	chown -R nobody:users /config/openvpn
	chmod -R 775 /config/openvpn

	# create the tunnel device
	[ -d /dev/net ] || mkdir -p /dev/net
	[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

	# get ip for local gateway (eth0)
	DEFAULT_GATEWAY=$(ip route show default | awk '/default/ {print $3}')

	# setup ip tables and routing for application
	source /root/iptable.sh

	# add in google public nameservers (isp may block ns lookup when connected to vpn)
	echo 'nameserver 8.8.8.8' > /etc/resolv.conf
	echo 'nameserver 8.8.4.4' >> /etc/resolv.conf

	echo "[info] nameservers"
	cat /etc/resolv.conf
	echo "--------------------"

	# start openvpn tunnel
	source /root/openvpn.sh

fi
