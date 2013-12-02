#!/bin/sh
# UTF-8



cleanBadInstall() {
	if [ -d "/opt/shibboleth-identityprovider" ]; then
		rm -rf /opt/shibboleth-identityprovider*
	fi
	if [ -d "/opt/cas-client-${casVer}" ]; then
		rm -rf /opt/cas-client-${casVer}
	fi
	if [ -d "/opt/ndn-shib-fticks" ]; then
		rm -rf /opt/ndn-shib-fticks
	fi
	if [ -d "/opt/shibboleth-idp" ]; then
		rm -rf /opt/shibboleth-idp
	fi
	if [ -d "/opt/mysql-connector-java-5.1.27" ]; then
		rm -rf /opt/mysql-connector-java-5.1.27
	fi
	if [ -f "/usr/share/tomcat6/lib/tomcat6-dta-ssl-1.0.0.jar" ]; then
		rm /usr/share/tomcat6/lib/tomcat6-dta-ssl-1.0.0.jar
	fi
	if [ -d "/opt/apache-maven-3.1.0/" ]; then
		rm -rf /opt/apache-maven-3.1.0/
	fi
	if [ -s "/etc/profile.d/maven-3.1.sh" ]; then
		rm -rf /etc/profile.d/maven-3.1.sh
	fi

	exit 1
}

setBackTitle ()
{
	#	echo "in setBackTitle"
		btVar="BackTitle${my_ctl_federation}"
	#echo "in setBackTitle btVar=${btVar}, ${!btVar}"

	BackTitle="${!btVar} ${BackTitle}"
	
	# used in script.eduroam.functions.sh
	GUIbacktitle="${BackTitle}"

}

installDependanciesForInstallation ()
{
	${Echo} "Updating repositories and installing generic dependancies"
	eval ${distCmdU} >> ${statusFile} 2>&1
	eval ${distCmd1} >> ${statusFile} 2>&1
}

fetchJavaIfNeeded ()

{

	# install java if needed
	javaBin=`which java 2>/dev/null`
	if [ ! -s "${javaBin}" ]; then
		eval ${distCmd3}
		javaBin=`which java 2>/dev/null`
	fi
	if [ ! -s "${javaBin}" ]; then
		${Echo} "No java could be found! Install a working JRE and re-run this script."
		cleanBadInstall
	fi

}

notifyMessageDeployBeginning ()
{
	${Echo} "Starting deployment!"
}


setVarUpgradeType ()

{

	if [ -L "/opt/shibboleth-identityprovider" -a -d "/opt/shibboleth-idp" ]; then
		upgrade=1
	fi

}

setVarPrepType ()

{
prep="prep/${type}"

}

setVarCertCN ()

{
certCN=`${Echo} ${idpurl} | cut -d/ -f3`

}

setJavaHome () {
	javaBin=`which java`
	if [ -z "${JAVA_HOME}" ]; then
		# check java
		if [ -L "${javaBin}" ]; then
			export JAVA_HOME=`readlink -f ${javaBin} | awk -F'bin' '{print $1}'`
		else
			if [ -s "${javaBin}" ]; then
				export JAVA_HOME=`${javaBin} -classpath ${Spath}/files/ getJavaHome`
			else
				${Echo} "No java found, please install JRE"
				cleanBadInstall
			fi
		fi
		if [ -z "`grep 'JAVA_HOME' /root/.bashrc`" ]; then
			${Echo} "export JAVA_HOME=${JAVA_HOME}" >> /root/.bashrc
		fi
	fi
}

setJavaCACerts ()
{
	# 	set path to ca cert file
	if [ -f "/etc/ssl/certs/java/cacerts" ]; then
		javaCAcerts="/etc/ssl/certs/java/cacerts"
	else
		javaCAcerts="${JAVA_HOME}/lib/security/cacerts"
	fi
}

generatePasswordsForSubsystems ()

{
	generate keystore pass
	if [ -z "${pass}" ]; then
		pass=`${passGenCmd}`
	fi
	if [ -z "${httpspass}" ]; then
		httpspass=`${passGenCmd}`
	fi
	if [ -z "${mysqlPass}" -a "${eptid}" != "n" ]; then
		mysqlPass=`${passGenCmd}`
		${Echo} "Mysql root password generated\nPassword is '${mysqlPass}'" >> ${messages}
	fi

}

guessLinuxDist() {
	lsbBin=`which lsb_release 2>/dev/null`
	if [ -x "${lsbBin}" ]
	then
		dist=`lsb_release -i 2>/dev/null | cut -d':' -f2 | sed -re 's/^\s+//g'`
	fi

	if [ ! -z "`${Echo} ${dist} | grep -i 'ubuntu' | grep -v 'grep'`" ]
	then
		dist="ubuntu"
	elif [ ! -z "`${Echo} ${dist} | grep -i 'redhat' | grep -v 'grep'`" ]
	then
		dist="redhat"
	elif [ -s "/etc/centos-release" ]
	then
		dist="centos"
	elif [ -s "/etc/redhat-release" ]
	then
		dist="redhat"
	else
		really=$(askYesNo "Distribution" "Can not guess linux distribution, procede assuming ubuntu(ish)?")

		if [ "${really}" != "n" ]
		then
			dist="ubuntu"
		else
			cleanBadInstall
		fi
	fi
}

askList() {
	title=$1
	text=$2
	list=$3
	string=""

	if [ "${GUIen}" = "y" ]; then
		WTcmd="${whiptailBin} --backtitle \"${BackTitle}\" --title \"${title}\" --nocancel --menu --clear -- \"${text}\" ${whipSize} 5 ${list} 3>&1 1>&2 2>&3"
		string=$(eval ${WTcmd})
	else
		${Echo} ${text} >&2
		${Echo} ${list} | sed -re 's/\"([^"]+)\"\ *\"([^"]+)\"\ */\1\ \-\-\ \2\n/g' >&2
		read string
		${Echo} "" >&2
	fi

	${Echo} "${string}"
}

askYesNo() {
	title=$1
	text=$2
	value=$3
	string=""

	if [ "${GUIen}" = "y" ]; then
		if [ ! -z "${value}" ]; then
			value="--defaultno "
		fi

		${whiptailBin} --backtitle "${BackTitle}" --title "${title}" ${value}--yesno --clear -- "${text}" ${whipSize} 3>&1 1>&2 2>&3
		stringNum=$?
		string="n"
		if [ "${stringNum}" -eq 0 ]; then
			string="y"
		fi
	else
		show=""
		if [ ! -z "${value}" ]; then
			show="${text} [y/N]: "
		else
			show="${text} [Y/n]: "
		fi

		${Echo} "${show}" >&2
		read string
		${Echo} "" >&2

		if [ ! -z "${value}" ]; then
			if [ "${string}" = "y" -o "${string}" = "Y" ]; then
				string="y"
			else
				string="n"
			fi
		else
			if [ "${string}" = "n" -o "${string}" = "N" ]; then
				string="n"
			else
				string="y"
			fi
		fi
	fi

	${Echo} "${string}"
}

askString() {
	title=$1
	text=$2
	value=$3
	null=$4
	string=""

	while [ -z "${string}" ]; do
		if [ "${GUIen}" = "y" ]; then
			string=$(${whiptailBin} --backtitle "${BackTitle}" --title "${title}" --nocancel --inputbox --clear -- "${text}" ${whipSize} "${value}" 3>&1 1>&2 2>&3)
		else
			show=${text}
			if [ ! -z "${value}" ]; then
				show="${show} [${value}]"
			fi
			${Echo} "${show}: " >&2
			read string
			${Echo} "" >&2
			if [ ! -z "${value}" -a -z "${string}" ]; then
				string=${value}
			fi
		fi

		if [ -z "${string}" -a ! -z "${null}" ]; then
			break
		fi
	done

	${Echo} "${string}"
}

installEPEL() {
	${Echo} "Installing jpackage & EPEL..."
	cat > /etc/yum.repos.d/jpackage-generic-free.repo << EOF
[jpackage-generic-free]
name=JPackage generic free
baseurl=http://ftp.heanet.ie/pub/jpackage/6.0/generic/free
mirrorlist=http://www.jpackage.org/mirrorlist.php?dist=generic&type=free&release=6.0
enabled=1
gpgcheck=1
gpgkey=http://www.jpackage.org/jpackage.asc
EOF

	cat > /etc/yum.repos.d/jpackage-generic-devel.repo << EOF
[jpackage-generic-devel]
name=JPackage Generic Developer
baseurl=http://ftp.heanet.ie/pub/jpackage/6.0/generic/free
mirrorlist=http://www.jpackage.org/mirrorlist.php?dist=generic&type=free&release=6.0
enabled=1
gpgcheck=1
gpgkey=http://www.jpackage.org/jpackage.asc
EOF

	eval $redhatEpel >> ${statusFile} 2>&1
}

setHostnames() {
	FQDN=`hostname`
	FQDN=`host -t A ${FQDN} | awk '{print $1}' | sed -re 's/\s+//g'`
	Dname=`${Echo} ${FQDN} | cut -d\. -f2-`
	if [ "${FQDN}" = "Host" ]
	then
		myInterface=`netstat -nr | grep "^0.0.0.0" | awk '{print $NF}'`
		myIP=`ip addr list ${myInterface} | grep "inet " | cut -d' ' -f6 | cut -d/ -f1`
		Dname=`host -t A ${myIP} | head -1 | awk '{print $NF}' | cut -d\. -f2- | sed 's/\.$//'`
		FQDN=`host -t A ${myIP} | head -1 | awk '{print $NF}' | sed 's/\.$//'`
	fi
}



fetchCas() {
	${Echo} "Cas-client not found, fetching from web"
	${fetchCmd} ${downloadPath}/cas-client-${casVer}-release.zip ${casClientURL}

	if [ ! -s ${downloadPath}/cas-client-${casVer}-release.zip ]; then
		${Echo} "Error while downloading CAS client, aborting."
		cleanBadInstall
	fi
}

fetchMysqlCon() {

	${fetchCmd} ${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz ${mysqlConnectorURL}
	
	if [ ! -s "${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz" ]; then
		${Echo} "Error while downloading mysql-connector, aborting."
		cleanBadInstall
	fi
}



installFticksIfEnabled() {

if [ "${fticks}" != "n" ]; then

		eval ${distCmd2} >> ${statusFile} 2>&1
		Cres=$?
		if [ $Cres -gt 0 ]; then
			${Echo} "Command failed: ${distCmd2}"
			cleanBadInstall
		fi
		if [ ! -s "`which mvn 2>/dev/null`" ]; then
			installMavenRC
		fi

		if [ ! -s "`which mvn 2>/dev/null`" ]; then
			${Echo} "Maven2 not found! Install Maven2 and re-run this script."
			cleanBadInstall
		fi


	${Echo} "Installing ndn-shib-fticks"
	eval ${distCmd2} >> ${statusFile} 2>&1
	if [ ! -x "`which mvn 2>/dev/null`" ]; then
		continueF=$(askYesNo "Maven2" "Make sure Maven2 is installed?\nContinue?" "no")

		if [ "${continueF}" = "n" ]; then
			cleanBadInstall
		fi
	fi

	cd /opt
	git clone git://github.com/leifj/ndn-shib-fticks.git >> ${statusFile} 2>&1
	cd ndn-shib-fticks
	mvn >> ${statusFile} 2>&1
	cp /opt/ndn-shib-fticks/target/*.jar /opt/shibboleth-identityprovider/lib

else
	${Echo} "NOT Installing ndn-shib-fticks"

fi


}

installEPTIDSupport ()
	{
	if [ "${eptid}" != "n" ]; then
		${Echo} "Installing EPTID support"
		if [ "${dist}" == "ubuntu" ]; then
			test=`dpkg -s mysql-server > /dev/null 2>&1`
			isInstalled=$?
		else
			test=`rpm -q mysql-serverd > /dev/null 2>&1`
			isInstalled=$?
		fi

		if [ "${isInstalled}" -ne 0 ]; then
			export DEBIAN_FRONTEND=noninteractive
			eval ${distCmd5} >> ${statusFile} 2>&1

			mysqldTest=`pgrep mysqld`
			if [ -z "${mysqldTest}" ]; then
				/etc/init.d/mysqld start >> ${statusFile} 2>&1
			fi
			# set mysql root password
			tfile=`mktemp`
			if [ ! -f "$tfile" ]; then
				return 1
			fi
			cat << EOM > $tfile
USE mysql;
UPDATE user SET password=PASSWORD("${mysqlPass}") WHERE user='root';
FLUSH PRIVILEGES;
EOM

			mysql --no-defaults -u root -h localhost <$tfile
			retval=$?
			rm -f $tfile
			if [ "${retval}" -ne 0 ]; then
				${Echo} "\n\n\nAn error has occurred in the configuration of the MySQL installation."
				${Echo} "Please correct the MySQL installation and make sure a root password is set and it is possible to log in using the 'mysql' command."
				${Echo} "When MySQL is working, re-run this script."
				cleanBadInstall
			fi

			if [ "${dist}" != "ubuntu" ]; then
				/sbin/chkconfig mysqld on
			fi
		fi

		fetchMysqlCon
		cd /opt
		tar zxf ${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz -C /opt >> ${statusFile} 2>&1
		cp /opt/mysql-connector-java-${mysqlConVer}/mysql-connector-java-${mysqlConVer}-bin.jar /opt/shibboleth-identityprovider/lib/

	fi



	}

installCasClientIfEnabled() {

if [ "${type}" = "cas" ]; then

	if [ ! -f "${downloadPath}/cas-client-${casVer}-release.zip" ]; then
		fetchCas
	fi
	unzip -q ${downloadPath}/cas-client-${casVer}-release.zip -d /opt
	if [ ! -s "/opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar" ]; then
		${Echo} "Unzip of cas-client failed, check zip file: ${downloadPath}/cas-client-${casVer}-release.zip"
		cleanBadInstall
	fi

	if [ -z "${idpurl}" ]; then
		idpurl=$(askString "IDP URL" "Please input the URL to this IDP (https://idp.xxx.yy)" "https://${FQDN}")
	fi

	if [ -z "${casurl}" ]; then
		casurl=$(askString "CAS URL" "Please input the URL to yourCAS server (https://cas.xxx.yy/cas)" "https://cas.${Dname}/cas")
	fi

	if [ -z "${caslogurl}" ]; then
		caslogurl=$(askString "CAS login URL" "Please input the Login URL to your CAS server (https://cas.xxx.yy/cas/login)" "${casurl}/login")
	fi

	cp /opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar /opt/shibboleth-identityprovider/lib/
	cp /opt/cas-client-${casVer}/modules/commons-logging-1.1.jar /opt/shibboleth-identityprovider/lib/
	mkdir /opt/shibboleth-identityprovider/src/main/webapp/WEB-INF/lib
	cp /opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar /opt/shibboleth-identityprovider/src/main/webapp/WEB-INF/lib
	cp /opt/cas-client-${casVer}/modules/commons-logging-1.1.jar /opt/shibboleth-identityprovider/src/main/webapp/WEB-INF/lib

	cat ${Spath}/${prep}/shibboleth-identityprovider-web.xml.diff.template \
		| sed -re "s#IdPuRl#${idpurl}#;s#CaSuRl#${caslogurl}#;s#CaS2uRl#${casurl}#" \
		> ${Spath}/${prep}/shibboleth-identityprovider-web.xml.diff
	files="`${Echo} ${files}` ${Spath}/${prep}/shibboleth-identityprovider-web.xml.diff"

	patch /opt/shibboleth-identityprovider/src/main/webapp/WEB-INF/web.xml -i ${Spath}/${prep}/shibboleth-identityprovider-web.xml.diff >> ${statusFile} 2>&1

else
	${Echo} "Authentication type: ${type}, CAS Client Not Requested"


fi



}

installTomcat() {
	isInstalled="4"
	if [ "${dist}" = "ubuntu" ]; then
		test=`dpkg -s tomcat6 > /dev/null 2>&1`
		isInstalled=$?
	else
		test=`rpm -q tomcat6 > /dev/null 2>&1`
		isInstalled=$?
	fi
	if [ "${isInstalled}" -ne 0 ]; then
		eval ${distCmd4}
		if [ "${dist}" != "ubuntu" ]; then
			/sbin/chkconfig tomcat6 on
		fi
	fi
}

fetchAndUnzipShibbolethIdP ()

{

	cd /opt

	if [ ! -f "${downloadPath}/shibboleth-identityprovider-${shibVer}-bin.zip" ]; then
		${Echo} "Shibboleth not found, fetching from web"
		${fetchCmd} ${downloadPath}/shibboleth-identityprovider-${shibVer}-bin.zip ${shibbURL}

		if [ ! -s ${downloadPath}/shibboleth-identityprovider-${shibVer}-bin.zip ]; then
		${Echo} "Error while downloading Shibboleth, aborting."
		cleanBadInstall
		fi
	fi

# 	unzip all files
	${Echo} "Unzipping dependancies"

	unzip -q ${downloadPath}/shibboleth-identityprovider-${shibVer}-bin.zip -d /opt
	chmod -R 755 /opt/shibboleth-identityprovider-${shibVer}
	ln -s shibboleth-identityprovider-${shibVer} shibboleth-identityprovider
}



createCertificatePathAndHome ()

{

mkdir -p ${certpath}
	

}



installCertificates()

{

# change to certificate path whilst doing this part
cd ${certpath}
${Echo} "Fetching TCS CA chain from web"
	${fetchCmd} ${certpath}/server.chain ${certificateChain}
	if [ ! -s "${certpath}/server.chain" ]; then
		${Echo} "Can not get the certificate chain, aborting install."
		cleanBadInstall
	fi

	${Echo} "Installing TCS CA chain in java cacert keystore"
	cnt=1
	for i in `cat ${certpath}server.chain | sed -re 's/\ /\*\*\*/g'`; do
		n=`${Echo} ${i} | sed -re 's/\*\*\*/\ /g'`
		${Echo} ${n} >> ${certpath}${cnt}.root
		ltest=`${Echo} ${n} | grep "END CERTIFICATE"`
		if [ ! -z "${ltest}" ]; then
			cnt=`expr ${cnt} + 1`
		fi
	done
	ccnt=1
	while [ ${ccnt} -lt ${cnt} ]; do
		md5finger=`keytool -printcert -file ${certpath}${ccnt}.root | grep MD5 | cut -d: -f2- | sed -re 's/\s+//g'`
		test=`keytool -list -keystore ${javaCAcerts} -storepass changeit | grep ${md5finger}`
		subject=`openssl x509 -subject -noout -in ${certpath}${ccnt}.root | awk -F= '{print $NF}'`
		if [ -z "${test}" ]; then
			keytool -import -noprompt -trustcacerts -alias "${subject}" -file ${certpath}${ccnt}.root -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1
		fi
		files="`${Echo} ${files}` ${certpath}${ccnt}.root"
		ccnt=`expr ${ccnt} + 1`
	done
	
}

askForConfigurationData() {
	if [ -z "${type}" ]; then
		tList=""
		tAccept=""
		tGo=0
		for i in `ls ${Spath}/prep | sed -re 's/\n/\ /g'`; do
			tDesc=`cat ${Spath}/prep/${i}/.desc`
			tList="`${Echo} ${tList}` \"${i}\" \"${tDesc}\""
			tAccept=`${Echo} ${tAccept} ${i}`
		done

		while [ ${tGo} -eq 0 ]; do
			type=$(askList "Authentication type" "Which authentication type do you want to use?" "${tList}")
			for i in ${tAccept}; do
				if [ "${i}" = "${type}" ]; then
					tGo=1
					break
				fi
			done
		done
	fi
	prep="prep/${type}"

	if [ -z "${google}" ]; then
		google=$(askYesNo "Attributes to Google" "Do you want to release attributes to google?\nSwamid, Swamid-test and testshib.org installed as standard" "no")
	fi

	if [ "${google}" != "n" -a -z "${googleDom}" ]; then
		googleDom=$(askString "Your Google domain name" "Please input your Google domain name (student.xxx.yy)." "student.${Dname}")
	fi

	if [ -z "${ntpserver}" ]; then
		ntpserver=$(askString "NTP server" "Please input your NTP server address." "ntp.${Dname}")
	fi

	if [ -z "${ldapserver}" ]; then
		ldapserver=$(askString "LDAP server" "Please input yout LDAP server(s) (ldap.xxx.yy).\n\nSeparate multiple servers with spaces.\nLDAPS is used by default." "ldap.${Dname}")
	fi

	if [ -z "${ldapbasedn}" ]; then
		ldapbasedn=$(askString "LDAP Base DN" "Please input your LDAP Base DN")
	fi

	if [ -z "${ldapbinddn}" ]; then
		ldapbinddn=$(askString "LDAP Bind DN" "Please input your LDAP Bind DN")
	fi

	if [ -z "${ldappass}" ]; then
		ldappass=$(askString "LDAP Password" "Please input your LDAP Password")
	fi

	if [ "${type}" = "ldap" -a -z "${subsearch}" ]; then
		subsearch=$(askYesNo "LDAP Subsearch" "Do you want to enable LDAP subtree search?")
		subsearch="false"
		if [ "${subsearchNum}" = "y" ]; then
			subsearch="true"
		fi
	fi

	if [ -z "${ninc}" ]; then
		ninc=$(askString "norEduPersonNIN" "Please specify LDAP attribute for norEduPersonNIN (YYYYMMDDnnnn)" "norEduPersonNIN")
	fi

	if [ -z "${idpurl}" ]; then
		idpurl=$(askString "IDP URL" "Please input the URL to this IDP (https://idp.xxx.yy)" "https://${FQDN}")
	fi

	if [ "${type}" = "cas" ]; then
		if [ -z "${casurl}" ]; then
			casurl=$(askString "CAS URL" "Please input the URL to yourCAS server (https://cas.xxx.yy/cas)" "https://cas.${Dname}/cas")
		fi

		if [ -z "${caslogurl}" ]; then
			caslogurl=$(askString "CAS login URL" "Please input the Login URL to your CAS server (https://cas.xxx.yy/cas/login)" "${casurl}/login")
		fi
	fi

	if [ -z "${certOrg}" ]; then
		certOrg=$(askString "Certificate organisation" "Please input organisation name string for certificate request")
	fi

	if [ -z "${certC}" ]; then
		certC=$(askString "Certificate country" "Please input country string for certificate request" "SE")
	fi

	if [ -z "${certAcro}" ]; then
		acro=""
		for i in ${certOrg}; do
			t=`${Echo} ${i} | cut -c1`
			acro="${acro}${t}"
		done

		certAcro=$(askString "Organisation acronym" "Please input organisation Acronym (eg. 'HiG')" "${acro}")
	fi

	if [ -z "${certLongC}" ]; then
		certLongC=$(askString "Country descriptor" "Please input country descriptor (eg. 'Sweden')" "Sweden")
	fi

	if [ -z "${fticks}" ]; then
		fticks=$(askYesNo "Send anonymous data" "Do you want to send anonymous usage data to SWAMID?\nThis is recommended")
	fi

	if [ -z "${eptid}" ]; then
		eptid=$(askYesNo "eduPersonTargetedID" "Do you want to install support for eduPersonTargetedID?\nThis is recommended")
	fi

	if [ "${eptid}" != "n" ]; then
		mysqlPass=$(askString "MySQL password" "Please input the root password for MySQL\n\nEmpty string generates new password" "" 1)
	fi

	if [ -z "${selfsigned}" ]; then
		selfsigned=$(askYesNo "Self signed certificate" "Create a self signed certificate for HTTPS?\n\nThis is NOT recommended! Only for testing purposes" "no")
	fi

	pass=$(askString "IDP keystore password" "Please input your IDP keystore password\n\nEmpty string generates new password" "" 1)
	httpspass=$(askString "HTTPS Keystore password" "Please input your Keystore password for HTTPS\n\nEmpty string generates new password" "" 1)
}

setDistCommands() {
	if [ ${dist} = "ubuntu" ]; then
		distCmdU=${ubuntuCmdU}
		distCmd1=${ubuntuCmd1}
		distCmd2=${ubuntuCmd2}
		distCmd3=${ubuntuCmd3}
		distCmd4=${ubuntuCmd4}
		distCmd5=${ubuntuCmd5}
		tomcatSettingsFile=${tomcatSettingsFileU}
	elif [ ${dist} = "centos" -o "${dist}" = "redhat" ]; then
		if [ ${dist} = "centos" ]; then
			redhatDist=`cat /etc/centos-release |cut -f3 -d' ' |cut -c1`
			distCmdU=${centosCmdU}
			distCmd1=${centosCmd1}
			distCmd2=${centosCmd2}
			distCmd3=${centosCmd3}
			distCmd4=${centosCmd4}
			distCmd5=${centosCmd5}
		else
			redhatDist=`cat /etc/redhat-release | cut -d' ' -f7 | cut -c1`
			distCmdU=${redhatCmdU}
			distCmd1=${redhatCmd1}
			distCmd2=${redhatCmd2}
			distCmd3=${redhatCmd3}
			distCmd4=${redhatCmd4}
			distCmd5=${redhatCmd5}
		fi
		tomcatSettingsFile=${tomcatSettingsFileC}

		if [ "$redhatDist" -eq "6" ]; then
			redhatEpel=${redhatEpel6}
		else
			redhatEpel=${redhatEpel5}
		fi

		if [ ! -z "`rpm -q epel-release | grep ' is not installed'`" ]; then
			
			# Consider this base requirement for system, or maybe move it to the installation phase for Shibboleth??
			#
			#continueF=$(askYesNo "Centos" "${Rmsg}")
			continueF="y"


			if [ "${continueF}" = "y" ]; then
				installEPEL
			fi
		fi

		if [ "`which host 2>/dev/null`" == "" ]; then
			${Echo} "Installing bind-utils..."
			yum -y -q install bind-utils >> ${statusFile} 2>&1
		fi
	fi
}

prepConfirmBox() {
	cat > ${downloadPath}/confirm.tx << EOM
Options passed to the installer:


Authentication type:       ${type}

Release to Google:         ${google}
Google domain name:        ${googleDom}

NTP server:                ${ntpserver}

LDAP server:               ${ldapserver}
LDAP Base DN:              ${ldapbasedn}
LDAP Bind DN:              ${ldapbinddn}
LDAP Subsearch:            ${subsearch}
norEduPersonNIN:           ${ninc}

IDP URL:                   ${idpurl}
CAS Login URL:             ${caslogurl}
CAS URL:                   ${casurl}

Cert org string:           ${certOrg}
Cert country string:       ${certC}
norEduOrgAcronym:          ${certAcro}
Country descriptor:        ${certLongC}

Usage data to SWAMID:      ${fticks}
EPTID support:             ${eptid}

Create self seigned cert:  ${selfsigned}
EOM
}

writeConfigFile() {
		cat > ${Spath}/config << EOM
type="${type}"
google="${google}"
googleDom="${googleDom}"
ntpserver="${ntpserver}"
ldapserver="${ldapserver}"
ldapbasedn="${ldapbasedn}"
ldapbinddn="${ldapbinddn}"
subsearch="${subsearch}"
idpurl="${idpurl}"
caslogurl="${caslogurl}"
casurl="${casurl}"
certOrg="${certOrg}"
certC="${certC}"
fticks="${fticks}"
eptid="${eptid}"
selfsigned="${selfsigned}"
ninc="${ninc}"
certAcro="${certAcro}"
certLongC="${certLongC}"
EOM
}

installMavenRC() {

maven2URL="http://mirror.its.dal.ca/apache/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.tar.gz"
maven2File="${maven2URL##*/}"

maven2Path=`basename ${maven2File}  -bin.tar.gz`

	if [ -a "/opt/${maven2Path}/bin/mvn" ]
	then
		echo "Maven detected as installed"
	else
		echo "Fetching Maven from ${maven2URL}"

		${fetchCmd} ${downloadPath}/${maven2File} "{$maven2URL}"
		cd /opt
		tar zxf ${downloadPath}/${maven2File} >> ${statusFile} 2>&1

		
	fi
	export PATH=${PATH}:${maven2Path}/bin	


#	if [ ! -s "${downloadPath}/apache-maven-3.1.0-bin.tar.gz" ]; then
#		${fetchCmd} ${downloadPath}/apache-maven-3.1.0-bin.tar.gz http://mirrors.gigenet.com/apache/maven/maven-3/3.1.0/binaries/apache-maven-3.1.0-bin.tar.gz >> ${statusFile} 2>&1
#	fi

#	if [ ! -d "/opt/apache-maven-3.1.1/bin/" ]; then
#		tar -zxf ${downloadPath}/apache-maven-3.1.0-bin.tar.gz -C /opt
#	fi
	if [ ! -s "/etc/profile.d/maven-3.1.sh" ]; then
		cat > /etc/profile.d/maven-3.1.sh << EOM
export M2_HOME=/opt/apache-maven-3.1.1
export M2=\$M2_HOME/bin
PATH=\$M2:\$PATH
EOM
	fi
	if [ -z "${M2_HOME}" ]; then
		. /etc/profile.d/maven-3.1.sh
	fi
}

configShibbolethXMLAttributeResolverForLDAP ()
{
	ldapServerStr=""
	for i in `${Echo} ${ldapserver}`; do
		ldapServerStr="`${Echo} ${ldapServerStr}` ldaps://${i}"
	done
	ldapServerStr=`${Echo} ${ldapServerStr} | sed -re 's/^\s+//'`
	cat ${Spath}/xml/attribute-resolver.xml.diff.template \
		| sed -re "s#LdApUrI#${ldapServerStr}#;s/LdApBaSeDn/${ldapbasedn}/;s/LdApCrEdS/${ldapbinddn}/;s/LdApPaSsWoRd/${ldappass}/" \
		| sed -re "s/NiNcRePlAcE/${ninc}/;s/CeRtAcRoNyM/${certAcro}/;s/CeRtOrG/${certOrg}/;s/CeRtC/${certC}/;s/CeRtLoNgC/${certLongC}/" \
		> ${Spath}/xml/attribute-resolver.xml.diff
	files="`${Echo} ${files}` ${Spath}/xml/attribute-resolver.xml.diff"

}

configTomcatServerXMLForPasswd ()
{

	# 	prepare config from templates
	cat ${Spath}/xml/server.xml.tomcat \
		| sed -re "s#ShIbBKeyPaSs#${pass}#;s#HtTpSkEyPaSs#${httpspass}#;s#HtTpSJkS#${httpsP12}#;s#TrUsTsToRe#${javaCAcerts}#" \
		> ${Spath}/xml/server.xml
	files="`${Echo} ${files}` ${Spath}/xml/server.xml"
}

runShibbolethInstaller ()

{
	# 	run shibboleth installer
	cd /opt/shibboleth-identityprovider
	${Echo} "Running shiboleth installer"
	sh install.sh -Didp.home.input="/opt/shibboleth-idp" -Didp.hostname.input="${certCN}" -Didp.keystore.pass="${pass}" >> ${statusFile} 2>&1

}

configShibbolethSSLForLDAPJavaKeystore()

{

# 	Fetch certificates from LDAP servers
	lcnt=1
	capture=0
	ldapCert="ldapcert.pem"
	${Echo} 'Fetching and installing certificates from LDAP server(s)'
	for i in `${Echo} ${ldapserver}`; do
		#Get certificate info
		${Echo} "QUIT" | openssl s_client -showcerts -connect ${i}:636 > ${certpath}${i}.raw 2>&1
		files="`${Echo} ${files}` ${certpath}${i}.raw"

		for j in `cat ${certpath}${i}.raw | sed -re 's/\ /\*\*\*/g'`; do
			n=`${Echo} ${j} | sed -re 's/\*\*\*/\ /g'`
			if [ ! -z "`${Echo} ${n} | grep 'BEGIN CERTIFICATE'`" ]; then
				capture=1
				if [ -s "${certpath}${ldapCert}.${lcnt}" ]; then
					lcnt=`expr ${lcnt} + 1`
				fi
			fi
			if [ ${capture} = 1 ]; then
				${Echo} ${n} >> ${certpath}${ldapCert}.${lcnt}
			fi
			if [ ! -z "`${Echo} ${n} | grep 'END CERTIFICATE'`" ]; then
				capture=0
			fi
		done
	done

	for i in `ls ${certpath}${ldapCert}.*`; do
		md5finger=`keytool -printcert -file ${i} | grep MD5 | cut -d: -f2- | sed -re 's/\s+//g'`
		test=`keytool -list -keystore ${javaCAcerts} -storepass changeit | grep ${md5finger}`
		subject=`openssl x509 -subject -noout -in ${i} | awk -F= '{print $NF}'`
		if [ -z "${test}" ]; then
			keytool -import -noprompt -alias "${subject}" -file ${i} -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1
		fi
		files="`${Echo} ${files}` ${i}"
	done

}

configTomcatSSLServerKey()

{

	#set up ssl store
	if [ ! -s "${certpath}server.key" ]; then
		${Echo} "Generating SSL key and certificate request"
		openssl genrsa -out ${certpath}server.key 2048 2>/dev/null
		openssl req -new -key ${certpath}server.key -out ${certREQ} -config ${downloadPath}/openssl.cnf -subj "/CN=${certCN}/O=${certOrg}/C=${certC}"
	fi
	if [ "${selfsigned}" = "n" ]; then
		${Echo} "Put the certificate from TCS in the file: ${certpath}server.crt" >> ${messages}
		${Echo} "Run: openssl pkcs12 -export -in ${certpath}server.crt -inkey ${certpath}server.key -out ${httpsP12} -name tomcat -passout pass:${httpspass}" >> ${messages}
	else
		openssl x509 -req -days 365 -in ${certREQ} -signkey ${certpath}server.key -out ${certpath}server.crt
		if [ ! -d "/opt/shibboleth-idp/credentials/" ]; then
			mkdir /opt/shibboleth-idp/credentials/
		fi
		openssl pkcs12 -export -in ${certpath}server.crt -inkey ${certpath}server.key -out ${httpsP12} -name tomcat -passout pass:${httpspass}
	fi
}

patchShibbolethLDAPLoginConfigs ()

{
	# 	application server specific
	if [ "${type}" = "ldap" ]; then
		ldapServerStr=""
		for i in `${Echo} ${ldapserver}`; do
			ldapServerStr="`${Echo} ${ldapServerStr}` ldap://${i}"
		done
		ldapServerStr="`${Echo} ${ldapServerStr} | sed -re 's/^\s+//'`"

		cat ${Spath}/${prep}/login.conf.diff.template \
			| sed -re "s#LdApUrI#${ldapServerStr}#;s/LdApBaSeDn/${ldapbasedn}/;s/SuBsEaRcH/${subsearch}/" \
			> ${Spath}/${prep}/login.conf.diff
		files="`${Echo} ${files}` ${Spath}/${prep}/login.conf.diff"
		patch /opt/shibboleth-idp/conf/login.config -i ${Spath}/${prep}/login.conf.diff >> ${statusFile} 2>&1
	fi

}

patchTomcatConfigs ()

{

	if [ ! -d "/usr/share/tomcat6/endorsed" ]; then
		mkdir /usr/share/tomcat6/endorsed
	fi
	for i in `ls /opt/shibboleth-identityprovider/endorsed/`; do
		if [ ! -s "/usr/share/tomcat6/endorsed/${i}" ]; then
			cp /opt/shibboleth-identityprovider/endorsed/${i} /usr/share/tomcat6/endorsed
		fi
	done

	. ${tomcatSettingsFile}
	if [ -z "`${Echo} ${JAVA_OPTS} | grep '/usr/share/tomcat6/endorsed'`" ]; then
		JAVA_OPTS="`${Echo} ${JAVA_OPTS} | sed -re 's/-Xmx128m//'` -Djava.endorsed.dirs=/usr/share/tomcat6/endorsed -Xms512m -Xmx512m -XX:MaxPermSize=128m"
		JAVA_OPTS="`${Echo} ${JAVA_OPTS} | sed -re 's/^\s+//'`"
		${Echo} "JAVA_OPTS=\"${JAVA_OPTS}\"" >> ${tomcatSettingsFile}
		if [ "${dist}" != "ubuntu" ]; then
			${Echo} 'JAVA_ENDORSED_DIRS="/usr/share/tomcat6/endorsed"' >> ${tomcatSettingsFile}
		fi
	else
		${Echo} "JAVA_OPTS for tomcat already configured" >> ${messages}
	fi
	if [ "${dist}" == "ubuntu" ]; then
		if [ "${AUTHBIND}" != "yes" ]; then
			${Echo} "AUTHBIND=yes" >> ${tomcatSettingsFile}
		else
			${Echo} "AUTHBIND for tomcat already configured" >> ${messages}
		fi
		tomcatSSLport="443"
	else
		if [ -z "`grep '7443' /etc/sysconfig/iptables`" ]; then
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 7443 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 8443 -j ACCEPT
			iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 7443
			iptables-save > /etc/sysconfig/iptables
		fi
		service iptables reload
		tomcatSSLport="7443"
	fi

	if [ ! -s "/usr/share/tomcat6/lib/tomcat6-dta-ssl-1.0.0.jar" ]; then
		${fetchCmd} /usr/share/tomcat6/lib/tomcat6-dta-ssl-1.0.0.jar ${tomcatDepend}

		if [ ! -s "/usr/share/tomcat6/lib/tomcat6-dta-ssl-1.0.0.jar" ]; then
			${Echo} "Can not get tomcat dependancy, aborting install."
			cleanBadInstall
		fi
	fi

	cp /etc/tomcat6/server.xml /etc/tomcat6/server.xml.${ts}
	cat ${Spath}/xml/server.xml | sed "s/tomcatSSLport/${tomcatSSLport}/" > /etc/tomcat6/server.xml
	chmod o-rwx /etc/tomcat6/server.xml

	tcatUser=`grep "^tomcat" /etc/passwd | cut -d: -f1`
	chown ${tcatUser} /etc/tomcat6/server.xml
	chown ${tcatUser} /opt/shibboleth-idp/metadata
	chown -R ${tcatUser} /opt/shibboleth-idp/logs/


	if [ -d "/var/lib/tomcat6/webapps/ROOT" ]; then
		mv /var/lib/tomcat6/webapps/ROOT /opt/disabled.tomcat6.webapps.ROOT
	fi
	if [ "${dist}" = "ubuntu" ]; then
		cp /usr/share/tomcat6/lib/servlet-api.jar /opt/shibboleth-idp/lib/
	fi



}

configShibbolethFederationValidationKey ()

{

${fetchCmd} ${idpPath}/credentials/md-signer.crt http://md.swamid.se/md/md-signer.crt
	cFinger=`openssl x509 -noout -fingerprint -sha1 -in ${idpPath}/credentials/md-signer.crt | cut -d\= -f2`
	cCnt=1
	while [ "${cFinger}" != "${mdSignerFinger}" -a "${cCnt}" -le 10 ]; do
		${fetchCmd} ${idpPath}/credentials/md-signer.crt http://md.swamid.se/md/md-signer.crt
		cFinger=`openssl x509 -noout -fingerprint -sha1 -in ${idpPath}/credentials/md-signer.crt | cut -d\= -f2`
		cCnt=`expr ${cCnt} + 1`
	done
	if [ "${cFinger}" != "${mdSignerFinger}" ]; then
		 ${Echo} "Fingerprint error on md-signer.crt!\nGet ther certificate from http://md.swamid.se/md/md-signer.crt and verify it, then place it in the file: ${idpPath}/credentials/md-signer.crt" >> ${messages}
	fi

}

patchShibbolethConfigs ()
{

# patch shibboleth config files
	${Echo} "Patching config files"
	mv /opt/shibboleth-idp/conf/attribute-filter.xml /opt/shibboleth-idp/conf/attribute-filter.xml.dist
	cp ${Spath}/files/attribute-filter.xml.swamid /opt/shibboleth-idp/conf/attribute-filter.xml
	patch /opt/shibboleth-idp/conf/handler.xml -i ${Spath}/${prep}/handler.xml.diff >> ${statusFile} 2>&1
	patch /opt/shibboleth-idp/conf/relying-party.xml -i ${Spath}/xml/relying-party.xml.diff >> ${statusFile} 2>&1
	patch /opt/shibboleth-idp/conf/attribute-resolver.xml -i ${Spath}/xml/attribute-resolver.xml.diff >> ${statusFile} 2>&1

	if [ "${google}" != "n" ]; then
		repStr='<!-- PLACEHOLDER DO NOT REMOVE -->'
		sed -i -e "/^${repStr}$/r ${Spath}/xml/google-filter.add" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-filter.xml
		cat ${Spath}/xml/google-relay.diff.template | sed -re "s/IdPfQdN/${certCN}/" > ${Spath}/xml/google-relay.diff
		files="`${Echo} ${files}` ${Spath}/xml/google-relay.diff"
		patch /opt/shibboleth-idp/conf/relying-party.xml -i ${Spath}/xml/google-relay.diff >> ${statusFile} 2>&1
		cat ${Spath}/xml/google.xml | sed -re "s/GoOgLeDoMaIn/${googleDom}/" > /opt/shibboleth-idp/metadata/google.xml
	fi

	if [ "${fticks}" != "n" ]; then
		patch /opt/shibboleth-idp/conf/logging.xml -i ${Spath}/xml/fticks.diff >> ${statusFile} 2>&1
		touch /opt/shibboleth-idp/conf/fticks-key.txt
		chown ${tcatUser} /opt/shibboleth-idp/conf/fticks-key.txt
	fi

	if [ "${eptid}" != "n" ]; then
		epass=`${passGenCmd}`
# 		grant sql access for shibboleth
		esalt=`openssl rand -base64 36 2>/dev/null`
		cat ${Spath}/xml/eptid.sql.template | sed -re "s#SqLpAsSwOrD#${epass}#" > ${Spath}/xml/eptid.sql
		files="`${Echo} ${files}` ${Spath}/xml/eptid.sql"

		${Echo} "Create MySQL database and shibboleth user."
		mysql -uroot -p"${mysqlPass}" < ${Spath}/xml/eptid.sql
		retval=$?
		if [ "${retval}" -ne 0 ]; then
			${Echo} "Failed to create EPTID database, take a look in the file '${Spath}/xml/eptid.sql.template' and corect the issue." >> ${messages}
			${Echo} "Password for the database user can be found in: /opt/shibboleth-idp/conf/attribute-resolver.xml" >> ${messages}
		fi
			
		cat ${Spath}/xml/eptid-AR.diff.template \
			| sed -re "s#SqLpAsSwOrD#${epass}#;s#Large_Random_Salt_Value#${esalt}#" \
			> ${Spath}/xml/eptid-AR.diff
		files="`${Echo} ${files}` ${Spath}/xml/eptid-AR.diff"

		patch /opt/shibboleth-idp/conf/attribute-resolver.xml -i ${Spath}/xml/eptid-AR.diff >> ${statusFile} 2>&1
		patch /opt/shibboleth-idp/conf/attribute-filter.xml -i ${Spath}/xml/eptid-AF.diff >> ${statusFile} 2>&1
	fi


}

updateMachineTime ()
{
	${Echo} "Updating time from: ${ntpserver}"
	/usr/sbin/ntpdate ${ntpserver} > /dev/null 2>&1

# 	add crontab entry for ntpdate
	test=`crontab -l 2>/dev/null | grep "${ntpserver}" | grep ntpdate`
	if [ -z "${test}" ]; then
		${Echo} "Adding crontab entry for ntpdate"
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
		if [ ! -z "${CRONTAB}" ]; then
			CRONTAB="${CRONTAB}\n"
		fi
		${Echo} "${CRONTAB}*/5 *  *   *   *     /usr/sbin/ntpdate ${ntpserver} > /dev/null 2>&1" | crontab
	fi
}

updateTomcatAddingIDPWar ()
{
	# 	add idp.war to tomcat
	if [ "${dist}" = "ubuntu" ]; then
		cp ${Spath}/xml/tomcat.idp.xml /var/lib/tomcat6/conf/Catalina/localhost/idp.xml
	else
		cp ${Spath}/xml/tomcat.idp.xml /etc/tomcat6/Catalina/localhost/idp.xml
		# make sure tomcat can see the file
		chown tomcat /etc/tomcat6/Catalina/localhost/idp.xml

	fi
}

restartTomcatService ()

{
	service tomcat6 restart
}


cleanupFilesRoutine ()
{

if [ "${cleanUp}" -eq 1 ]; then
# 	remove configs with templates
	for i in ${files}; do
		rm ${i}
	done
else
	${Echo} "Files created by script"
	for i in ${files}; do
		${Echo} ${i}
	done
fi

}
notifyUserBeforeExit()
{

	${Echo} "\n\n\n"

	if [ "${selfsigned}" = "n" ]; then
		cat ${certREQ}
		${Echo} "Here is the certificate request, go get at cert!"
		${Echo} "Or replace the cert files in ${certpath}"
		${Echo} "\n\nNOTE!!! the keystore for https is a PKCS12 store\n\n"
	fi
	${Echo} ""
	${Echo} "Register at testshib.org and register idp, and run a logon test."
	${Echo} "Certificate for idp metadata is in the file: /opt/shibboleth-idp/credentials/idp.crt"

if [ "${type}" = "ldap" ]; then
	${Echo} "\n\n"
	${Echo} "Read this to customize the logon page: https://wiki.shibboleth.net/confluence/display/SHIB2/IdPAuthUserPassLoginPage"
fi



}



showAndCleanupMessagesFile ()

{

if [ -s "${messages}" ]; then
	cat ${messages}
	rm ${messages}
fi

}


askForSaveConfigToLocalDisk ()
{

cAns=$(askYesNo "Save config" "Do you want to save theese config values?\n\nIf you save theese values the current config file will be ovverwritten.\n NOTE: No passwords will be saved.")

	if [ "${cAns}" = "y" ]; then
		writeConfigFile
	fi

	if [ "${GUIen}" = "y" ]; then
		${whiptailBin} --backtitle "SWAMID IDP Deployer" --title "Confirm" --scrolltext --clear --textbox ${downloadPath}/confirm.tx 20 75 3>&1 1>&2 2>&3
	else
		cat ${downloadPath}/confirm.tx
	fi
	cAns=$(askYesNo "Confirm" "Do you want to install this IDP with theese options?" "no")

	rm ${downloadPath}/confirm.tx
	if [ "${cAns}" = "n" ]; then
		exit
	fi

}

performStepsForShibbolethUpgradeIfRequired ()

{

if [ "${upgrade}" -eq 1 ]; then

${Echo} "Previous installation found, performing upgrade."

	eval ${distCmd1}
	cd /opt
	currentShib=`ls -l /opt/shibboleth-identityprovider | awk '{print $NF}'`
	currentVer=`${Echo} ${currentShib} | awk -F\- '{print $NF}'`
	if [ "${currentVer}" = "${shibVer}" ]; then
		mv ${currentShib} ${currentShib}.${ts}
	fi

	if [ ! -f "${downloadPath}/shibboleth-identityprovider-${shibVer}-bin.zip" ]; then
		fetchShibboleth
	fi
	unzip -q ${downloadPath}/shibboleth-identityprovider-${shibVer}-bin.zip -d /opt
	chmod -R 755 /opt/shibboleth-identityprovider-${shibVer}

	unlink /opt/shibboleth-identityprovider
	ln -s /opt/shibboleth-identityprovider-${shibVer} /opt/shibboleth-identityprovider

	if [ -d "/opt/cas-client-${casVer}" ]; then
		installCasClientIfEnabled
	fi

	if [ -d "/opt/ndn-shib-fticks" ]; then
		if [ -z "`ls /opt/ndn-shib-fticks/target/*.jar`" ]; then
			cd /opt/ndn-shib-fticks
			mvn >> ${statusFile} 2>&1
		fi
		cp /opt/ndn-shib-fticks/target/*.jar /opt/shibboleth-identityprovider/lib
	else
		fticks=$(askYesNo "Send anonymous data" "Do you want to send anonymous usage data to SWAMID?\nThis is recommended")

		if [ "${fticks}" != "n" ]; then
			installFticksIfEnabled
		fi
	fi

	if [ -d "/opt/mysql-connector-java-${mysqlConVer}/" ]; then
		cp /opt/mysql-connector-java-${mysqlConVer}/mysql-connector-java-${mysqlConVer}-bin.jar /opt/shibboleth-identityprovider/lib/
	fi

	cd /opt
	tar zcf ${bupFile} shibboleth-idp

	cp /opt/shibboleth-idp/metadata/idp-metadata.xml /opt/shibboleth-identityprovider/src/main/webapp/metadata.xml

	setJavaHome
	cd /opt/shibboleth-identityprovider
	${Echo} "\n\n\n\nRunning shiboleth installer"
	sh install.sh -Dinstall.config=no -Didp.home.input="/opt/shibboleth-idp" >> ${statusFile} 2>&1
else
	${Echo} "\nNot an Upgrade but a fresh Shibboleth Install"


fi


}

invokeShibbolethInstallProcess ()
{

	### Begin of SAML IdP installation Process


	# check for installed IDP
	setVarUpgradeType

	# Override per federation
	performStepsForShibbolethUpgradeIfRequired

	askForConfigurationData
	prepConfirmBox

	askForSaveConfigToLocalDisk

	notifyMessageDeployBeginning


	setVarPrepType
	setVarCertCN

	installDependanciesForInstallation

	fetchJavaIfNeeded

	setJavaHome
	
	setJavaCACerts

	generatePasswordsForSubsystems

	installTomcat
	
	

	fetchAndUnzipShibbolethIdP

	
	installCasClientIfEnabled
	

	installFticksIfEnabled

	installEPTIDSupport



	configTomcatServerXMLForPasswd

	configShibbolethXMLAttributeResolverForLDAP
	

	runShibbolethInstaller


	createCertificatePathAndHome

	
	# Override per federation
	installCertificates

	configShibbolethSSLForLDAPJavaKeystore

	# Override per federation
	configTomcatSSLServerKey

	patchShibbolethLDAPLoginConfigs

	patchTomcatConfigs
	
	# Override per federation
	configShibbolethFederationValidationKey

	patchShibbolethConfigs

	updateMachineTime

	updateTomcatAddingIDPWar


restartTomcatService


}