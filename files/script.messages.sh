#!/bin/sh
# UTF-8

mdSignerFinger="12:60:D7:09:6A:D9:C1:43:AD:31:88:14:3C:A8:C4:B7:33:8A:4F:CB"
GUIen=y
cleanUp=1
upgrade=0
shibVer="2.4.4"
casVer="3.3.3"
mysqlConVer="5.1.34"
javaVer="1.8.0_25"

# This URL determines which base to derive 'latest' from
# --> this is the very very latest: jettyBaseURL="http://download.eclipse.org/jetty/stable-9/dist/"
# Below is the 9.2.11 one
jettyBaseURL="http://archive.eclipse.org/jetty/9.2.11.v20150529/dist/"


files=""
ts=`date "+%s"`
whiptailBin=`which whiptail`
if [ ! -x "${whiptailBin}" ]
then
	GUIen="n"
fi

#
# used in eduroam configs
#
backupPath="${Spath}/backups/"
templatePath="${Spath}/assets"
templatePathEduroamCentOS="${Spath}/assets/etc/raddb"
templatePathEduroamCentOS7="${Spath}/assets/etc/raddb7"
templatePathEduroamUbuntu="${Spath}/assets/etc/freeradius"
templatePathEduroamRedhat="${Spath}/assets/etc/raddb"
CentOSEduroamModules="/modules"
CentOS7EduroamModules="/mods-available"
UbuntuEduroamModules="/modules"
RedhatEduroamModules="/modules"
downloadPath="${Spath}/downloads"
backupList="${backupPath}/recoverypoints.txt"
freeradiusfile="${Spath}/files/freeradius.tx"


mainMenuExitFlag=0
whipSize="13 75"
certpath="/opt/shibboleth-idp/ssl/"
httpsP12="/opt/shibboleth-idp/credentials/https.p12"
certREQ="${certpath}tomcat.req"
passGenCmd="openssl rand -base64 20"
messages="${Spath}/msg.txt"
statusFile="${Spath}/status.log"
bupFile="/opt/backup-shibboleth-idp.${ts}.tar.gz"
idpPath="/opt/shibboleth-idp/"
certificateChain="http://webkonto.hig.se/chain.pem"
tomcatDepend="https://build.shibboleth.net/nexus/content/repositories/releases/edu/internet2/middleware/security/tomcat6/tomcat6-dta-ssl/1.0.0/tomcat6-dta-ssl-1.0.0.jar"
jettyDepend="https://build.shibboleth.net/nexus/content/repositories/releases/net/shibboleth/utilities/jetty9/jetty9-dta-ssl/1.0.0/jetty9-dta-ssl-1.0.0.jar"
dist=""
distCmdU=""
distCmdUa=""
distCmd1=""
distCmd5=""
dist_install_nc=""
dist_install_netstat=""
dist_install_ldaptools=""
distCmdEduroam=""
distEduroamPath=""
distRadiusGroup=""
templatePathEduroamDist=""
distEduroamModules=""
fetchCmd="curl --silent -k --output"
shibbURL="http://shibboleth.net/downloads/identity-provider/${shibVer}/shibboleth-identityprovider-${shibVer}-bin.zip"
casClientURL="http://developer.jasig.org/cas-clients/cas-client-${casVer}-release.zip"
mysqlConnectorURL="http://ftp.sunet.se/pub/unix/databases/relational/mysql/Downloads/Connector-J/mysql-connector-java-${mysqlConVer}.tar.gz"
Rmsg="Do you want to install 'EPEL' and 'jpackage' to automaticly install dependancies? (Without theese depends the install WILL fail!)"

# Titles for the whiptail environment for branding
BackTitleSWAMID="SWAMID"
BackTitleCAF="Canadian Access Federation"
BackTitle="IDP Deployer"

# define commands
ubuntuCmdU="apt-get update"
ubuntuCmdUa="apt-get -y upgrade"
ubuntuCmd1="apt-get -y install patch ntp unzip curl"
ubuntuCmd5="apt-get -y install mysql-server"
tomcatSettingsFileU="/etc/default/tomcat6"
ubutnu_install_nc="apt-get -y install netcat"
ubuntu_install_ldaptools="apt-get -y install ldap-utils"
ubuntuEduroamPath="/etc/freeradius"
ubuntuRadiusGroup="freerad"

redhatCmdU="yum -y update"
redhatCmd1="yum -y install patch ntpdate unzip curl"
redhatCmd5="yum -y install mysql-server"
redhat_install_nc="yum -y install nc"
redhat_install_netstat="yum -y install net-tools"
redhat_install_ldaptools="yum -y install openldap-clients"
redhatEduroamPath="/etc/raddb"
redhatRadiusGroup="radiusd"

ubuntuCmdEduroam="apt-get install -y ntp samba winbind freeradius freeradius-krb5 freeradius-ldap freeradius-utils freeradius-mysql make"
redhatCmdEduroam="yum -y install bind-utils net-tools samba samba-winbind samba-winbind-clients freeradius freeradius-krb5 freeradius-ldap freeradius-perl freeradius-python freeradius-utils freeradius-mysql make" 
#redhatCmdFedSSO="yum -y install java-1.6.0-openjdk-devel tomcat6 mysql-server mysql"
centosCmdEduroam="yum -y install bind-utils net-tools samba samba-winbind samba-winbind-clients freeradius freeradius-krb5 freeradius-ldap freeradius-perl freeradius-python freeradius-utils freeradius-mysql make" 
centosCmdFedSSO="yum -y install java-1.6.0-openjdk-devel tomcat6 mysql-server mysql"

centosCmdU="yum -y update"
centosCmdUa="yum clean all"
centosCmd1="yum -y install patch ntpdate unzip curl"
centosCmd5="yum -y install mysql-server"
tomcatSettingsFileC="/etc/sysconfig/tomcat6"
centos_install_nc="yum -y install nc"
centos_install_netstat="yum -y install net-tools"
centos_install_ldaptools="yum -y install openldap-clients"
centosEduroamPath="/etc/raddb"
centosRadiusGroup="radiusd"

redhatEpel5="rpm -Uvh http://download.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm"
redhatEpel6="rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"


# info for validation of required fields for deployer options
# one long list but broken apart into sections similar to the HTML installer page
# excluded ones: my_eduroamDomain (used on HTML page but nowhere else)
#				 installer_* are not needed either EXCEPT for: installer_section0_buildComponentList which is the list of features to activate
#
# SPECIAL NOTE: It would be prudent to keep these fields in sync with the required fields in the HTML page
#
# The variable names are specifically not Camel cased on the last element (eduroam, shibboleth)
# to allow them to be assembled as needed so we can just have a list for the next 'element' that may be used
# see the ValidateConfig() function where these will be processed

requiredNonEmptyFieldseduroam=" krb5_libdef_default_realm krb5_realms_def_dom krb5_domain_realm smb_workgroup smb_netbios_name smb_passwd_svr smb_realm"
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_realm freeRADIUS_cdn_prod_passphrase freeRADIUS_pxycfg_realm"
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_clcfg_ap1_ip freeRADIUS_clcfg_ap1_secret freeRADIUS_clcfg_ap2_ip freeRADIUS_clcfg_ap2_secret"
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_ca_state freeRADIUS_ca_local freeRADIUS_ca_org_name freeRADIUS_ca_email freeRADIUS_ca_commonName" 
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_svr_state freeRADIUS_svr_local freeRADIUS_svr_org_name freeRADIUS_svr_email freeRADIUS_svr_commonName"

requiredNonEmptyFieldsshibboleth=" appserv type idpurl ntpserver ldapserver ldapbinddn ldappass ldapbasedn subsearch fticks eptid google ninc"

requiredEnforceConnectivityFieldseduroam="smb_passwd_svr ldapserver"
requiredEnforceConnectivityFieldsshibboleth="ldapserver"
