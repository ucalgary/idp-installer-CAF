#!/bin/sh
# UTF-8
setInstallStatus() {


# check for installed IDP
msg_FSSO="Federated SSO/Shibboleth:"
msg_RADIUS="eduroam read FreeRADIUS:"

if [ -L "/opt/shibboleth-identityprovider" -a -d "/opt/shibboleth-idp" ]
then
        msg_fsso_stat="Installed"
	installStateFSSO=1
else
	msg_fsso_stat="Not Installed yet"
	installStateFSSO=0
fi

if [ -L "${distEduroamPath}/sites-enabled/eduroam-inner-tunnel" -a -d "${distEduroamPath}" ]
then
        msg_freeradius_stat="Installed"
	installStateEduroam=1
else
        msg_freeradius_stat="Not Installed yet"
	installStateEduroam=0
fi
getStatusString="System state:\n${msg_FSSO} ${msg_fsso_stat}\n${msg_RADIUS} ${msg_freeradius_stat}"

}

refresh() {
			
			${whiptailBin} --backtitle "${GUIbacktitle}" --title "Deploy/Refresh relevant eduroam software base" --defaultno --yes-button "Yes, proceed" --no-button "No, back to main menu" --yesno --clear -- \
                        "Create restore point and refresh machine to CAF eduroam base?" ${whipSize} 3>&1 1>&2 2>&3
                	continueFwipe=$?
                	if [ "${continueFwipe}" -eq 0 ]
                	then
				eval ${distCmdEduroam} &> >(tee -a ${statusFile})	
				echo ""
				echo "Update Completed" >> ${statusFile} 2>&1 
                	fi
			
			displayMainMenu

}
review(){

 if [ "${GUIen}" = "y" ]
                then
                        ${whiptailBin} --backtitle "${GUIbacktitle}" --title "Review Install Settings" --ok-button "Return to Main Menu" --scrolltext --clear --textbox ${freeradiusfile} 20 75 3>&1 1>&2 2>&3

		displayMainMenu

                else
			echo "Please make sure whiptail is installed"
                fi


}

modifyIPTABLESForEduroam ()
{
	${Echo} "Updating IPTABLES configuration to permit eduroam UDP ports, 1812,1813,1814 to be accepted"

iptables -A INPUT -m udp -p udp --dport 1812 -j ACCEPT
iptables -A INPUT -m udp -p udp --dport 1813 -j ACCEPT
iptables -A INPUT -m udp -p udp --dport 1814 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

}

deployEduroamCustomizations() {
	
	# flat copy of files from deployer to OS
	
	cp ${templatePath}/etc/nsswitch.conf.template /etc/nsswitch.conf

	cp ${templatePathEduroamDist}/sites-available/default.template ${distEduroamPath}/sites-available/default
	cp ${templatePathEduroamDist}/sites-available/eduroam.template ${distEduroamPath}/sites-available/eduroam
	cp ${templatePathEduroamDist}/sites-available/eduroam-inner-tunnel.template ${distEduroamPath}/sites-available/eduroam-inner-tunnel
	if [ ${dist} != "ubuntu" -a ${redhatDist} = "7"  ]; then
		cp ${templatePathEduroamDist}/eap.conf.template ${distEduroamPath}/mods-available/eap
	else
		cp ${templatePathEduroamDist}/eap.conf.template ${distEduroamPath}/eap.conf
	fi
	chgrp ${distRadiusGroup} ${distEduroamPath}/sites-available/*
	
	# remove and redo symlink for freeRADIUS sites-available to sites-enabled

(cd ${distEduroamPath}/sites-enabled;rm -f eduroam-inner-tunnel; ln -s ../sites-available/eduroam-inner-tunnel eduroam-inner-tunnel)
(cd ${distEduroamPath}/sites-enabled;rm -f eduroam; ln -s ../sites-available/eduroam)
	#rm -f ${distEduroamPath}/sites-available/eduroam-inner-tunnel
	#ln -s ${distEduroamPath}/sites-available/eduroam-inner-tunnel ${distEduroamPath}/sites-enabled/eduroam-inner-tunnel
	#rm -f ${distEduroamPath}/sites-available/eduroam
	#ln -s ${distEduroamPath}/sites-available/eduroam ${distEduroamPath}/sites-enabled/eduroam

	# do parsing of templates into the right spot
	# in order as they appear in the variable list
	
# /etc/krb5.conf	
	cat ${templatePath}/etc/krb5.conf.template \
	|perl -npe "s#kRb5_LiBdEf_DeFaUlT_ReAlM#${krb5_libdef_default_realm}#" \
	|perl -npe "s#kRb5_DoMaIn_ReAlM#${krb5_domain_realm}#" \
	|perl -npe "s#Host_kRb5_rEaLmS_dEf_DoM#${smb_netbios_name}.${krb5_realms_def_dom}#" \
	|perl -npe "s#kRb5_rEaLmS_dEf_DoM#${krb5_realms_def_dom}#" \
	> /etc/krb5.conf

# /etc/samba/smb.conf
	cat ${templatePath}/etc/samba/smb.conf.template \
	|perl -npe "s#sMb_WoRkGrOuP#${smb_workgroup}#" \
	|perl -npe "s#sMb_NeTbIoS_NaMe#${smb_netbios_name}#" \
	|perl -npe "s#sMb_PaSsWd_SvR#${smb_passwd_svr}#" \
	|perl -npe "s#sMb_ReAlM#${smb_realm}#" \
	> /etc/samba/smb.conf

# ${distEduroamPath}/modules
	### /mods-enabled doesn't exist after installtion !?!?
        #ln -s ${distEduroamPath}/mods-enabled ${distEduroamPath}/modules
	cat ${templatePathEduroamDist}/modules/mschap.template \
	|perl -npe "s#fReErAdIuS_rEaLm#${freeRADIUS_realm}#" \
	|perl -npe "s#PXYCFG_rEaLm#${freeRADIUS_pxycfg_realm}#" \
	 > ${distEduroamPath}${distEduroamModules}/mschap
	chgrp ${distRadiusGroup} ${distEduroamPath}${distEduroamModules}/mschap

# ${distEduroamPath}/radiusd.conf
	cat ${templatePathEduroamDist}/radiusd.conf.template \
	|perl -npe "s#fReErAdIuS_rEaLm#${freeRADIUS_realm}#" \
	> ${distEduroamPath}/radiusd.conf
	chgrp ${distRadiusGroup} ${distEduroamPath}/radiusd.conf

# ${distEduroamPath}/proxy.conf
	cat ${templatePathEduroamDist}/proxy.conf.template \
	|perl -npe "s#fReErAdIuS_rEaLm#${freeRADIUS_realm}#" \
	|perl -npe "s#PrOd_EduRoAm_PhRaSe#${freeRADIUS_cdn_prod_passphrase}#" \
	> ${distEduroamPath}/proxy.conf
	chgrp ${distRadiusGroup} ${distEduroamPath}/proxy.conf

# ${distEduroamPath}/clients.conf 
	cat ${templatePathEduroamDist}/clients.conf.template \
	|perl -npe "s#PrOd_EduRoAm_PhRaSe#${freeRADIUS_cdn_prod_passphrase}#" \
	|perl -npe "s#CLCFG_YaP1_iP#${freeRADIUS_clcfg_ap1_ip}#" \
	|perl -npe "s#CLCFG_YaP1_sEcReT#${freeRADIUS_clcfg_ap1_secret}#" \
	|perl -npe "s#CLCFG_YaP2_iP#${freeRADIUS_clcfg_ap2_ip}#" \
	|perl -npe "s#CLCFG_YaP2_sEcReT#${freeRADIUS_clcfg_ap2_secret}#" \
 	> ${distEduroamPath}/clients.conf
	chgrp ${distRadiusGroup} ${distEduroamPath}/clients.conf

# ${distEduroamPath}/certs/ca.cnf (note that there are a few things in the template too like setting it to 10yrs validity )
mod_freeRADIUS_svr_email=`echo "${freeRADIUS_svr_email}" | sed 's/@/\\\\@/'`
mod_freeRADIUS_ca_email=`echo "${freeRADIUS_ca_email}" | sed 's/@/\\\\@/'`

	cat ${templatePathEduroamDist}/certs/ca.cnf.template \
	|perl -npe "s#CRT_Ca_StAtE#${freeRADIUS_ca_state}#" \
	|perl -npe "s#CRT_Ca_LoCaL#${freeRADIUS_ca_local}#" \
	|perl -npe "s#CRT_Ca_OrGnAmE#${freeRADIUS_ca_org_name}#" \
	|perl -npe "s#CRT_Ca_EmAiL#${mod_freeRADIUS_ca_email}#" \
	|perl -npe "s#CRT_Ca_CoMmOnNaMe#${freeRADIUS_ca_commonName}#" \
 	> ${distEduroamPath}/certs/ca.cnf
	
# ${distEduroamPath}/certs/server.cnf (note that there are a few things in the template too like setting it to 10yrs validity )
	cat ${templatePathEduroamDist}/certs/server.cnf.template \
	|perl -npe "s#CRT_SvR_StAtE#${freeRADIUS_svr_state}#" \
	|perl -npe "s#CRT_SvR_LoCaL#${freeRADIUS_svr_local}#" \
	|perl -npe "s#CRT_SvR_OrGnAmE#${freeRADIUS_svr_org_name}#" \
	|perl -npe "s#CRT_SvR_EmAiL#${mod_freeRADIUS_svr_email}#" \
	|perl -npe "s#CRT_SvR_CoMmOnNaMe#${freeRADIUS_svr_commonName}#" \
 	> ${distEduroamPath}/certs/server.cnf

# ${distEduroamPath}/certs/client.cnf (note that there are a few things in the template too like setting it to 10yrs validity )
	cat ${templatePathEduroamDist}/certs/client.cnf.template \
	|perl -npe "s#CRT_SvR_StAtE#${freeRADIUS_svr_state}#" \
	|perl -npe "s#CRT_SvR_LoCaL#${freeRADIUS_svr_local}#" \
	|perl -npe "s#CRT_SvR_OrGnAmE#${freeRADIUS_svr_org_name}#" \
	|perl -npe "s#CRT_SvR_EmAiL#'${mod_freeRADIUS_svr_email}'#" \
	|perl -npe "s#CRT_SvR_CoMmOnNaMe#${freeRADIUS_svr_commonName}#" \
 	> ${distEduroamPath}/certs/client.cnf

	echo "Merging variables completed " >> ${statusFile} 2>&1 

# construct default certificates including a CSR for this host in case a commercial CA is used

#	WARNING, see the ${distEduroamPath}/certs/README to 'clean' out certificate bits when you run
#		this script respect the protections freeRADIUS put in place to not overwrite certs
if [ "${dist}" != "ubuntu"  ]; then
	if [ "${redhatDist}" != "7" ]; then
		if [  -e "${distEduroamPath}/certs/server.crt" ] 
		then
			echo "bootstrap already run, skipping"
		else
		
			(cd ${distEduroamPath}/certs; ./bootstrap )
		fi
	else
		(cd ${distEduroamPath}/certs; make destroycerts; make clean; ./bootstrap )
		chown root:radiusd ${distEduroamPath}/certs/*
	fi
else
	dd if=/dev/urandom of=${distEduroamPath}/certs/random count=10
	cp ${templatePathEduroamDist}/certs/bootstrap ${distEduroamPath}/certs/bootstrap
	cp ${templatePathEduroamDist}/certs/xpextensions ${distEduroamPath}/certs/xpextensions
	rm ${distEduroamPath}/certs/ca.pem; rm ${distEduroamPath}/certs/server.key; rm ${distEduroamPath}/certs/server.pem
	(cd ${distEduroamPath}/certs; ./bootstrap )
fi

# ensure proper start/stop at run level 3 for the machine are in place for winbind,smb, and of course, radiusd
	if [ "${dist}" != "ubuntu" ]; then
		ckCmd="/sbin/chkconfig"
		ckArgs="--level 3"
		ckState="on" 
		ckServices="winbind smb radiusd"

		for myService in $ckServices
		do
			${ckCmd} ${ckArgs} ${myService} ${ckState}
		done
	fi

# disable SELinux as it interferes with the winbind process.
	if [ "${dist}" != "ubuntu" ]; then

	echo "updating SELinux to disable it" >> ${statusFile} 2>&1 
	cp ${templatePath}/etc/sysconfig/selinux.template /etc/sysconfig/selinux 

	fi
# add radiusd/freerad to group wbpriv/winbindd_priv 
	if [ "${dist}" != "ubuntu" ]; then
		echo "adding user radiusd to WINBIND/SAMBA privilege group wbpriv" >> ${statusFile} 2>&1 
		usermod -a -G wbpriv radiusd
	else
		echo "adding user freerad to WINBIND/SAMBA privilege group winbindd_priv" >> ${statusFile} 2>&1
		usermod -a -G winbindd_priv freerad
	fi

# tweak winbind to permit proper authentication traffic to proceed
# without this, the NTLM call out for freeRADIUS will not be able to process requests
if [ "${redhatDist}" != "7" ]; then
	if [ "${dist}" != "ubuntu" ]; then
		chmod ugo+rx /var/run/winbindd
	else
	    	chown root:winbindd_priv /var/lib/samba/winbindd_privileged/				
	fi
fi

# disable iptables on runlevels 3,4,5 for reboot and then disable it right now for good measure

#	echo "Disabling iptables" >> ${statusFile} 2>&1 
#	${ckCmd} --level 3 iptables off
#	${ckCmd} --level 4 iptables off
#	${ckCmd} --level 5 iptables off
#	/sbin/service iptables stop
if [ "${redhatDist}" != "7" ]; then
	if [ "${dist}" != "ubuntu" ]; then
		modifyIPTABLESForEduroam
	fi
fi

echo "Start Up processes completed" >> ${statusFile} 2>&1 

	
}



doInstallEduroam() {
	if [ "${installer_interactive}" = "y" ]; then
		${whiptailBin} --backtitle "${GUIbacktitle}" --title "Deploy eduroam customizations" --defaultno --yes-button "Yes, proceed" --no-button "No, back to main menu" --yesno --clear -- "Proceed with deploying Canadian Access Federation(CAF) eduroam settings?" ${whipSize} 3>&1 1>&2 2>&3
		continueFwipe=$?
	else
		continueFwipe=0
	fi

	if [ "${continueFwipe}" -eq 0 ]; 
	then
		eval ${distCmdEduroam} &> >(tee -a ${statusFile})
		echo ""
		echo "Update Completed" >> ${statusFile} 2>&1 
		echo "Beginning overlay , creating Restore Point" >> ${statusFile} 2>&1

		createRestorePoint
		deployEduroamCustomizations

		if [ "${installer_interactive}" = "y" ]; then
			${whiptailBin} --backtitle "${GUIbacktitle}" --title "eduroam customization completed"  --msgbox "Congratulations! eduroam customizations are now deployed!\n\nNext steps: Join this machine to the AD domain by typing \n\nnet [ads|rpc] join -U Administrator -S ad.server.domain.ca\n\n After, reboot the machine and it should be ready to answer requests. \n\nDecide on your commercial certificate: Self Signed certificates were generated by default. A CSR is located at ${distEduroamPath}/certs/server.csr to request a commercial one. Remember the RADIUS extensions needed though!\n\nFor further configuration details, please see the documentation on disk or the web \n\n Choose OK to return to main menu." 22 75
		fi
	else
		if [ "${installer_interactive}" = "y" ]; then
			${whiptailBin} --backtitle "${GUIbacktitle}" --title "eduroam customization aborted" --msgbox "eduroam customizations WERE NOT done. Choose OK to return to main menu" ${whipSize} 
		fi
	fi
}


doInstallFedSSO() {
        if [ "${installer_interactive}" = "y" ]
        then
                ${whiptailBin} --backtitle "${GUIbacktitle}" --title "Deploy Shibboleth customizations" --defaultno --yes-button "Yes, proceed" --no-button "No, back to main menu" --yesno --clear -- "Proceed with deploying Shibboleth and related settings?" ${whipSize} 3>&1 1>&2 2>&3
                continueFwipe=$?
        else
                continueFwipe=0
        fi

        if [ "${continueFwipe}" -eq 0 ]; then

                echo "Beginning overlay , creating Restore Point" >> ${statusFile} 2>&1

                createRestorePoint
                invokeShibbolethInstallProcessJetty9

                if [ "${installer_interactive}" = "y" ]; then
                        ${whiptailBin} --backtitle "${GUIbacktitle}" --title "Shibboleth customization completed"  --msgbox "Congratulations! Shibboleth customizations are now deployed!\n\n Choose OK to return to main menu." 22 75
                fi
        else
                if [ "${installer_interactive}" = "y" ]; then
                        ${whiptailBin} --backtitle "${GUIbacktitle}" --title "Shibboleth customization aborted" --msgbox "Shibboleth customizations WERE NOT done. Choose OK to return to main menu" ${whipSize}
                fi
        fi
}



displayMainMenu() {

	if [ "${installer_interactive}" = "y" ]
	then
		if [ "${GUIen}" = "y" ]
		then
			#${whiptailBin} --backtitle "${GUIbacktitle}" --title "Review and Confirm Install Settings" --scrolltext --clear --defaultno --yesno --textbox ${freeradiusfile} 20 75 3>&1 1>&2 2>&3
			#eduroamTask=$(${whiptailBin} --backtitle "${GUIbacktitle}" --title "Identity Server Main Menu" --cancel-button "exit, no changes" menu --clear  -- "${getStatusString}\nWhich do you want to do?" ${whipSize} 2 review "install Settings" refresh "relevant CentOS packages" install "full eduroam base server" 20 75 3>&1 1>&2 2>&3)

			eduroamTask=$(${whiptailBin} --backtitle "${GUIbacktitle}" --title "Identity Server Main Menu" --cancel-button "exit" --menu --clear  -- "Which do you want to do?" ${whipSize} 5 refresh "Refresh relevant CentOS packages" review "Review install Settings" installEduroam "Install only the eduroam service" installFedSSO "Install only Federated SSO service" rollBack "Restore previous Shibboleth V2 setup" installAll "Install eduroam and Federated SSO services" 3>&1 1>&2 2>&3)


		else
			echo "eduroam tasks[ install| uninstall ]"
			read eduroamTask
			echo ""
		fi
	else
		installEduroam=$(echo "${installer_section0_buildComponentList}" | grep "eduroam")
		installFedSSO=$(echo "${installer_section0_buildComponentList}" | grep "shibboleth")

		if [ ! -z "${installEduroam}" ] && [ ! -z "${installFedSSO}" ]
		then
			eduroamTask="installAll"
		elif [ ! -z "${installEduroam}" ]
		then
			eduroamTask="installEduroam"
		elif [ ! -z "${installFedSSO}" ]
		then
			eduroamTask="installFedSSO"
		fi

		mainMenuExitFlag=1
	fi

	if [ "${eduroamTask}" = "review" ]
	then
		echo "review selected!"
		review
	elif [ "${eduroamTask}" = "refresh" ]
	then	

		echo "refresh chosen, creating Restore Point" >> ${statusFile} 2>&1
		createRestorePoint
		refresh

	elif [ "${eduroamTask}" = "installEduroam" ]
	then

		if echo "${installer_section0_buildComponentList}" | grep -q "eduroam"; then


			echo "install chosen, creating Restore Point" >> ${statusFile} 2>&1
			createRestorePoint
			echo "Restore Point Completed" >> ${statusFile} 2>&1
			invokeEduroamInstallProcess
			echo "Update Completed" >> ${statusFile} 2>&1

			doInstallEduroam
		else
			echo "Sorry, necessary configuration for eduroam is incomplete, please redo config file"
			exit

		fi


	elif [ "${eduroamTask}" = "installFedSSO" ]
                then


                        if echo "${installer_section0_buildComponentList}" | grep -q "shibboleth"; then


                                        echo "install of Federated SSO chosen, creating Restore Point" >> ${statusFile} 2>&1
						         		createRestorePoint
                                        
                                        echo "Restore Point Completed" >> ${statusFile} 2>&1
                               
                                 		doInstallFedSSO
                               
                                        echo "Update Completed" >> ${statusFile} 2>&1

                        else
                                echo "Sorry, necessary configuration for shibboleth is incomplete, please redo config file"
                                exit
	                fi

        elif [ "${eduroamTask}" = "rollBack" ]  
                then
			if [ -d /opt/bak ]; then

	                        service jetty stop
        	                rm -rf /opt/shibboleth-idp
				rm -rf /opt/shibboleth-identity-provider* /opt/jetty* /usr/java/
                	        cp -ar /opt/bak /opt/shibboleth-idp
                        	service tomcat6 start
			else
                                echo "Sorry, nothing to restore."
                                exit
			fi

	elif [ "${eduroamTask}" = "installAll" ]
	then


		echo "install everything chosen, creating Restore Point" >> ${statusFile} 2>&1
		createRestorePoint
		echo "Restore Point Completed" >> ${statusFile} 2>&1
		echo "Installing FreeRADIUS and eduroam configuration" >> ${statusFile} 2>&1
		invokeEduroamInstallProcess
		doInstallEduroam
		echo "Installing Shibboleth and Federated SSO configuration" >> ${statusFile} 2>&1

		doInstallFedSSO

		echo ""
		echo "Update Completed" >> ${statusFile} 2>&1

		#doInstallEduroam
	else

		mainMenuExitFlag=1

	fi

}
createRestorePoint() {
	# Creates a restore point. Note the tar command starts from / and uses . prefixed paths.
	# this should permit easier, less error prone untar of the file on same machine if needed
	
	rpLabel="RestorePoint-`date +%F-%s`"
	rpFile="${backupPath}/Identity-Appliance-${rpLabel}.tar"

	# record our list of backups
	echo "${rpLabel} ${rpFile}" >> ${backupList}
	bkpCmd="(cd /;tar cfv ${rpFile} ./etc/krb5.conf ./etc/samba .${distEduroamPath}) >> ${statusFile} 2>&1"
	
	eval ${bkpCmd}

}





invokeEduroamInstallProcess ()

{

eval ${distCmdEduroam} &> >(tee -a ${statusFile})

}
