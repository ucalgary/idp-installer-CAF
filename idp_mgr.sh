#!/bin/bash
Spath="$(cd "$(dirname "$0")" && pwd)"
if [ ! -z "`echo ${Spath} | grep \"/bin$\"`" ]; then
	Spath=`dirname ${Spath}`
fi

. ${Spath}/files/script.messages.sh
. ${Spath}/files/script.bootstrap.functions.sh
setEcho
hostPort=""
url=""

if [ ! -s "/opt/jetty/jetty-base/start.d/idp.ini" ]; then
	if [ -z "${1}" ]; then
		${Echo} "Can't find dependancies, aborting.\nPlease run this script with the HTTPS port as an argument"
		exit 1
	else
		hostPort=${1}
	fi
else
	hostPort="`grep \"^jetty.https.port=\" /opt/jetty/jetty-base/start.d/idp.ini | cut -d= -f2-`"
fi

taskList="aacli ' ' metadata ' ' reload ' '"

askListLargeCancel() {
	local title=$1
	local text=$2
	local list=$3
	local noItem="--noitem"
	if [ ! -z "${4}" ]; then
		noItem=""
	fi
	local string=""

	if [ "${GUIen}" = "y" ]; then
		local WTcmd="${whiptailBin} --backtitle \"${BackTitle}\" --title \"${title}\" --menu ${noItem} --clear -- \"${text}\" 20 75 12 ${list} 3>&1 1>&2 2>&3"
		string=$(eval ${WTcmd})
	else
		${Echo} ${text} >&2
		${Echo} "" >&2
		${Echo} ${list} | sed -re 's/\"([^"]+)\"\ *\"([^"]+)\"\ */\1\ \-\-\ \2\n/g' | sed -re "s/\ '\ '\ ?/\n/g" >&2
		read string
		${Echo} "" >&2
	fi

	${Echo} "${string}"
}

findCipher() {
	local port=$1
	local cipher=""
	for i in `openssl ciphers |sed 's/:/\ /g'`; do
		echo "QUIT" | openssl s_client -connect localhost:${port} -quiet -cipher ${i} >/dev/null 2>&1
		ret=$?
		if [ ${ret} -eq 0 ]; then
			cipher=${i}
			break
		fi
	done
	if [ "x${cipher}" == "x" ]; then
		${Echo} "No suitable cipher found, can't make request to server." 1>&2
		exit 1
	else
		${Echo} ${cipher}
	fi
}

task=$(askListLargeCancel "Choose task" "Please choose a task." "${taskList}")
if [ -z "${task}" ]; then
	${Echo} "Cancel"
	exit
fi

if [ "${task}" = "aacli" ]; then
	princ=""
	entID=""

	princ=$(askString "Enter principal" "Please enter your principal, ie. username." "" "1")
	if [ -s "/opt/shibboleth-idp/conf/attribute-filter.xml" ]; then
		ids="`cat /opt/shibboleth-idp/conf/attribute-filter.xml | awk 'in_comment&&/-->/{sub(/([^-]|-[^-])*--+>/,\"\");in_comment=0} in_comment{next} {gsub(/<!--+([^-]|-[^-])*--+>/,\"\"); in_comment=sub(/<!--+.*/,\"\"); print}' | grep 'xsi:type=\"Requester\"' | awk -F'value=' '{ print $2 }' | cut -d\\\" -f2`"
	fi
	idList=$(
		for i in ${ids}; do
			echo "${i} ' '"
		done
		echo "InputBox ' '"
	)
	entID=$(askListLargeCancel "Choose entityID" "Please choose a entityID or select 'InputBox' to enter another." "${idList}")
	if [ "${entID}" = "InputBox" ]; then
		entID=$(askString "Enter requestor entityID" "Please enter the requestor entityID." "" "1")
	fi

	if [ -z "${princ}" -o -z "${entID}" ]; then
		${Echo} "Not enough data supplied"
		exit
	fi

	extras="None '- No extra option' saml2 '- Display full saml2:Assertion' saml1 '- Display full saml1:Assertion'"
	extra=$(askListLargeCancel "Extra options" "Do you want to add an extra option to the request?" "${extras}" " ")
	if [ "${extra}" == "None" -o "x${extra}" == "x" ]; then
		extra=""
	else
		extra="&${extra}"
	fi

	url="/idp/profile/admin/resolvertest?requester=${entID}&principal=${princ}${extra}"
elif [ "${task}" = "metadata" ]; then
	if [ ! -s "/opt/shibboleth-idp/conf/metadata-providers.xml" ]; then
		${Echo} "Can't find the file metadata-providers.xml, aborting."
		exit 1
	fi

	provider=""
	idList="`cat /opt/shibboleth-idp/conf/metadata-providers.xml | awk 'in_comment&&/-->/{sub(/([^-]|-[^-])*--+>/,\"\");in_comment=0} in_comment{next} {gsub(/<!--+([^-]|-[^-])*--+>/,\"\"); in_comment=sub(/<!--+.*/,\"\"); print}' | sed '/^[\ \t]*$/d' | grep '<MetadataProvider' | awk -F' id=' '{print $2}' | cut -d\\\" -f2 | tr '\n' ' '`"
	provList=$(
		for i in ${idList}; do
			if [ ${i} = "ShibbolethMetadata" ]; then
				echo "${i} ' - All metadata'"
			else
				echo "${i} ' '"
			fi
		done
	)

	provider=$(askListLargeCancel "Reload IDP metadata" "Please choose which metadata feed id you want to reload." "${provList}" "1")
	if [ -z "${provider}" ]; then
		${Echo} "Cancel"
		exit
	fi

	url="/idp/profile/admin/reload-metadata?id=${provider}"
elif [ "${task}" = "reload" ]; then
	if [ ! -s "/opt/shibboleth-idp/system/conf/services-system.xml" ]; then
		${Echo} "Can't find the file services-system.xml, aborting."
		exit 1
	fi

	service=""
	servList=$(
		for i in `grep 'class="net.shibboleth.ext.spring.service' /opt/shibboleth-idp/system/conf/services-system.xml | cut -d\" -f2 | grep "^shibboleth"`; do
			echo "${i} ' '"
		done
		echo "shibboleth.LoggingService ' '"
	)

	service=$(askListLargeCancel "Reload IDP component" "Please choose which IDP component you want to reload." "${servList}")
	if [ -z "${service}" ]; then
		${Echo} "Cancel"
		exit
	fi

	url="/idp/profile/admin/reload-service?id=${service}"
fi

cipher=$(findCipher ${hostPort})
${Echo} "GET ${url} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" | openssl s_client -connect localhost:${hostPort} -quiet -cipher ${cipher} 2>/dev/null | awk '{ if (/^\s*$/) x=1; if (x==1) print; }'

if [ "${task}" != "aacli" ]; then
	${Echo} "\nPlease check /opt/shibboleth-idp/logs/idp-process.log for potential errors."
fi

