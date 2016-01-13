#!/bin/bash
Spath="$(cd "$(dirname "$0")" && pwd)"
if [ ! -z "`echo ${Spath} | grep \"/bin$\"`" ]; then
	Spath=`dirname ${Spath}`
fi

#git pull

. ${Spath}/files/script.messages.sh
. ${Spath}/files/script.bootstrap.functions.sh
setEcho
. ${Spath}/files/script.functions.sh

cd ${Spath}

installOracleJava
