#!/bin/bash
TARGETS="pihole1 pihole2"
ID="id_dnsdhcp"

FILES="pihole/hosts.local dnsmasq.d/02.local.conf dnsmasq.d/04-pihole-static-dhcp.conf"

CHANGED=0
for TARGET in ${TARGETS}; do
	for F in ${FILES}; do 
		#echo ${F}
		EF="/etc/${F}"
		scp -i ${ID} -q ${F} root@${TARGET}:${EF}.new
		ssh -i ${ID} root@${TARGET} "test -f ${EF} && diff -u ${EF} ${EF}.new"
		if [ $? != 0 ]; then
			ssh -i ${ID} root@${TARGET} "test -f ${EF} && mv ${EF} ${EF}.old; mv ${EF}.new ${EF}"
			CHANGED=1
		else 
			ssh -i ${ID} root@${TARGET} "rm ${EF}.new"
		fi
	done

	if [ ${CHANGED} == 1 ]; then
		echo "Files changed, reloading ${TARGET}!";
		ssh -i ${ID} root@${TARGET} "service pihole-FTL restart"
		if [ $? != 0 ]; then
			echo "Got an error code restarting pihole-FTL on ${TARGET}, exiting!"
			exit 1
		fi
	fi

done
