#!/bin/sh
servername=$1
if [[ "$2" = "ping" ]]
then
    #####################################################################################################
    #<<<<<<<< valiating the connectivity through ping command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>#
    #####################################################################################################
    ping -c1 -W1 $servername > /dev/null 2>&1 && pingFlag=0 || pingFlag=-1
    if [[ "${pingFlag}" -ne 0 ]]
    then
            echo "Ping Status : false"
    else
            echo "Ping Status : true"
    fi
elif [[ "$2" = "ssh" ]]
then
    #####################################################################################################
    #<<<<<<<< valiating the connectivity through ssh command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>>#
    #####################################################################################################
    ssh -n "isauto@${servername}" "exit" > /dev/null 2>&1 && sshFlag=0 || sshFlag=-1
    if [[ "${sshFlag}" -ne 0 ]]
    then
            echo "SSH Status : false"
    else
            echo "SSH Status : true"
    fi
elif [[ "$2" = "remote_cmd_execution" ]]
then
    ssh -n isauto@${servername} "$3"
else
    echo "command not found."
fi
