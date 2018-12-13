#!/bin/sh
#########################################################################################################################
# Name of the script            : mks_terminate_user_account
# Purpose of the script         : This script has been used to terminate a unix account on different linux platform.
# Extension of the script       : sh
#
# Developed By                  : ARUNKUMAR PERUMAL
# Developed On                  : 12/05/2018 (MM/DD/YYYY)
#
# Last Modified By              : ARUNKUMAR PERUMAL
# Last Modified On              : 12/05/2018 (MM/DD/YYYY)
#
# Latest Version                : 0.001
#########################################################################################################################

#Global Variables - PART 1
NodeFile=/depot/MKS/Linux/sysadm/.usernodes
#NodeFile=/home/sys_pr_uxaut01/.usernodes # For Internal Demo
NisMaster=ptc-avnis701 #ptc-avnis701
TermedADOnNISMaster=no
Termed_NIS_User=no
UserOnNIS=no
PushNis=no
NSUDCount=0
NUDServerList=[]
LSUDCount=0
UDLocalServerList=[]
CountOfIdentificationFoundOnSAMBA=0
CountOfIdentificationFoundOnLocal=0
MissedCountOnSAMBA=0
MissedCountOnLocal=0
MAFLocalServerCount=0
MAFLocalServer=[]
NISPushFailureCount=0
NOW=$(date +"%m/%d/%Y %H:%M:%S")
ReturnCode=2000
#sed 's/^[ \t]*//'
echo "<<<<<<<<< Unix Account Termination Script  >>>>>>>>>>>"
echo "                               "
echo "Execution Start Date Time of Terminate User Script : ${NOW}"

AD_Name=`echo $1 | sed 's/^[ \t]*//'`

#<<<<<<<<<<<<<<<< Validating Parameter of the script - Begin >>>>>>>>>>>>>>>>>>>>>>>
#Validated requested user account is not null or not and parameter count is 1 or not.
if [[ "$#" -ne 1 && "${AD_Name}" == "" ]]
then
  ReturnCode=4002 # ERROR CODE : Required Parameter Not Available.
  echo "                               "
  echo "ERROR : The AD Name of an Unix Account is missing."
  echo "Return Code : ${ReturnCode}"
  exit 34
fi

#Validating requested user account is root or not.
if [[ "${AD_Name}" == "root" ]]
then
        ReturnCode=4005 # ERROR CODE : Requested AD Name is matching with root user account.
        echo "                               "
        echo "ERROR : The requested AD Name is Root Account. Automation will not handle root accounts."
        echo "Return Code : ${ReturnCode}"
        exit 34
fi
#<<<<<<<<<<<<<<<< Validating Parameter of the script - End >>>>>>>>>>>>>>>>>>>>>>>

if [[ ! -f "${NodeFile}" ]]
then
  ReturnCode=4001 # ERROR CODE : Node File Not Found
  echo "                               "
  echo "ERROR : The file was not found which contains nodes information"
  echo "Return Code : ${ReturnCode}"
  exit 34
fi

#<<<<<<<<<<<<<<<<<< Function to get the current datetime >>>>>>>>>>>>>>>>>>>
Get_Timestamp ()
{
   Date=`date +%m%d%Y.%H%M%S`
}


#Global Variable - PART 2
N=`cat "${NodeFile}" | grep -v ^# | wc -l`
NCOUNT=0
NRNCount=0
NRNodes=[]

echo "                               "
echo "Number of servers : ${N}"

for Node in `cat ${NodeFile} | grep -v ^#`
do
        echo "                               "
        echo "CURRENT NODE : ${Node}       "
        NCOUNT=$(($NCOUNT + 1))
        echo "  Checking $NCOUNT of $N hosts"
        currentPingFlag=-1
        ping -c1 -W1 $Node > /dev/null 2>&1 && currentPingFlag=0 || currentPingFlag=-1
        currentSSHFlag=-1
        ssh -q root@${Node} exit > /dev/null 2>&1 && currentSSHFlag=0 || currentSSHFlag=-1
        if [[ "${currentPingFlag}" -ne 0 || "${currentSSHFlag}" -ne 0 ]]
        then
                [[ "${currentPingFlag}" -ne 0 ]] && echo "Server Ping Status : Down" || echo "Server SSH  Status : Up"
                [[ "${currentSSHFlag}" -ne 0 ]] && echo "Server SSH  Status : Down" || echo "Server SSH  Status : Up"
                NRNodes[${NRNCount}]=${Node}
                NRNCount=$(($NRNCount + 1))
        else
                echo "   Server Ping Status : Up"
                echo "   Server SSH  Status : Up"
                #echo "ssh root@$Node cat /etc/passwd | grep ^${AD_Name}: | grep -iv 'term -' | grep -iv ^root: | awk -F: '{print $3}'"
                Found_It=`ssh root@$Node cat /etc/passwd | grep ^${AD_Name}: | grep -iv ^root: | awk -F: '{print $3}'`
                isMultipleIdFound=`ssh root@$Node cat /etc/passwd | grep ^${AD_Name}: | grep -iv ^root: | awk -F: '{print $3}' | wc -l`
                #User Identification
                if [ "${Found_It}" -a "${isMultipleIdFound}" -le 2 ]
                then
                        Get_Timestamp
                        echo "UID : ${Found_It}"
                        #echo "${Node} = ${NisMaster}"
                        if [ "${Found_It}" -a "${Node}" = "${NisMaster}" ]
                        then
                                # NIS PART
                                PushNis=PN
                                TermedADOnNISMaster=ADOnNIS
                                Termed_AD_User=no
                                CountOfIdentificationFoundOnSAMBA=$(($CountOfIdentificationFoundOnSAMBA + 1))
                                echo "<<<<<<<<<<<<<< Terminating $AD_Name on $Node (NIS Master Server) >>>>>>>>>>>>>>"
                                Term_Name=${AD_Name}
                                TermLine=`ssh root@${NisMaster} grep ^${Term_Name}: /etc/passwd`
                                FullShell=`ssh root@${NisMaster} grep ^${Term_Name}: /etc/passwd | awk -F: '{print $7}'`
                                GIDComments=`ssh root@${NisMaster} grep ^${Term_Name}: /etc/passwd | awk -F: '{print $5}'`
                                ShortShell=`basename ${FullShell}`
                                ssh root@${NisMaster} "cp /etc/passwd /etc/passwd.${Date}.term.$Term_Name" # comment it for testing purpose
                                #ssh root@${NisMaster} "usermod -c \"TERM - ${GIDComments}\" -s /bin/nologin $Term_Name" # This line not required
                                ssh root@${NisMaster} "userdel $AD_Name" #please comment it for local testing.
                                TermUserRC=$? #comment it for local testing.
                                isUserTerminated=`ssh root@${NisMaster} cat /etc/passwd | grep ^${AD_Name}: | awk -F: '{print $3}'`
                                #TermUserRC=0
                                if [[ "${TermUserRC}" -eq 0 && ( ! "${isUserTerminated}" ) ]]
                                then
                                        # diabled/terminated a user account successfully
                                        echo "User Termination Status On NIS Master Server : Success"
                                        #the script of remshell push on NisMaster - Start
                                        ssh -l root $NisMaster "cd /var/yp && /usr/ccs/bin/make passwd" #comment it for sit testing.
                                        exitcode=$? # comment it for testing purpose
                                        #exitcode=0
                                        if [ $exitcode -eq 0 ]
                                        then
                                          echo "The NIS Master Information was pushed successfully"
                                        else
                                          echo "The NIS Master push did not succeed, please run the push manually"
                                          NISPushFailureCount=$(($NISPushFailureCount + 1))
                                        fi
                                        #the script of remshell push on NisMaster - End
                                else
                                        # Unable to disable or terminate user account successfully
                                        echo "User Termination Status On NIS Master Server : Failed"
                                        PushNis=no
                                        Termed_NIS_User=no
                                        MissedCountOnSAMBA=$(($MissedCountOnSAMBA + 1))
                                fi
                        else
                                # LOCAL SERVER PART
                                CountOfIdentificationFoundOnLocal=$(($CountOfIdentificationFoundOnLocal + 1))
                                echo "<<<<<<<<<<<<<< Terminating $AD_Name on $Node (Local Node) >>>>>>>>>>>>>>"
                                ssh root@${Node} "userdel $AD_Name" #commented for testing purpose
                                countOfSameHomeDir=`ssh root@${Node} "ls -lntr /home | grep ${AD_Name} | grep -v grep | wc -l"`
                                ssh root@${Node} "mv /home/$AD_Name /home/${AD_Name}_terminated_$(($countOfSameHomeDir + 1))"
                                isUserTerminated=`ssh root@$Node cat /etc/passwd | grep ^${AD_Name}: | awk -F: '{print $3}'`
                                if [[ ! "${isUserTerminated}" ]]
                                then
                                        echo "User Termination Status : Success"
                                        UDLocalServerList[${LSUDCount}]=${Node}
                                        LSUDCount=$(($LSUDCount + 1))
                                else
                                        echo "User Termination Status : Failed"
                                        NUDServerList[${NSUDCount}]=${Node}
                                        NSUDCount=$(($NSUDCount + 1))
                                        MissedCountOnLocal=$(($MissedCountOnLocal + 1))
                                fi
                        fi
                elif [ "${isMultipleIdFound}" -ge 2 ]
                then
                        MAFLocalServer[${MAFLocalServerCount}]=${Node}
                        MAFLocalServerCount=$(($MAFLocalServerCount + 1))
                fi
        fi
done





#Conclusion Part
echo "Count of Local Server where we found a requested ${AD_Name} Account : ${CountOfIdentificationFoundOnLocal}"
echo "Count of NIS Master Server where we found a requested ${AD_Name} Account : ${CountOfIdentificationFoundOnSAMBA}"
echo "Report Generation Started"
echo "Missed on Local : ${MissedCountOnLocal}"
echo "Missed On Nis : ${MissedCountOnSAMBA}"
echo "NisPushFailureCount : ${NISPushFailureCount}"
echo "NRN count : ${NRNCount}"
echo "MAFLocalServerCount : ${MAFLocalServerCount}"
echo "CountOfIdentificationFoundOnSAMBA : ${CountOfIdentificationFoundOnSAMBA}"
echo "CountOfIdentificationFoundOnLocal : ${CountOfIdentificationFoundOnLocal}"
if [[ "${MissedCountOnLocal}" -gt 0 || "${MissedCountOnSAMBA}" -gt 0 || "${NISPushFailureCount}" -gt 0 || "${NRNCount}" -gt 0 || "${MAFLocalServerCount}" -gt 0 ]]
then
        ReturnCode=2010 # WARNING CODE : Some Server were not able to reachable using script.
        # Multiple Account Found


        # Not Reachable Server.
        if [[ "${NRNCount}" -gt 0 || "${MAFLocalServerCount}" -gt 0 ]]
        then
                echo "                                           "
                echo "<<<<<<<<< NOT REACHABLE SERVERS >>>>>>>>>>>"
                echo "                                           "
                echo "Number of not reachable nodes : ${NRNCount}"
                echo "                                           "
                echo "We were not able to reach the below servers"
                for (( i = 0 ; i < ${#NRNodes[@]} ; i++ ))
                do
                        echo -e "\t$(($i+1)). ${NRNodes[$i]}"
                done
                echo "                                           "
                if [[ "${MAFLocalServerCount}" -gt 0 ]]
                then
                        echo "<<<<<<<<< LIST OF SERVERS WHERE MORE THAN ONE USER ACCOUNT FOUND >>>>>>>>>>>"
                        echo "                                           "
                        echo "Number of nodes with multiple account exist : ${MAFLocalServerCount}"
                        for (( i = 0 ; i < ${#MAFLocalServerCount[@]} ; i++ ))
                        do
                                echo -e "\t$(($i+1)). ${MAFLocalServerCount[$i]}"
                        done
                fi
                echo "                                           "
                if [[ ( "${MissedCountOnSAMBA}" -eq 0 && "${NISPushFailureCount}" -eq 0 && "${CountOfIdentificationFoundOnSAMBA}" -gt 0 ) || ( "${MissedCountOnLocal}" -eq 0 && "${CountOfIdentificationFoundOnLocal}" -gt 0 ) ]]
                then
                        if [[ "${CountOfIdentificationFoundOnLocal}" -gt 0 && "${CountOfIdentificationFoundOnSAMBA}" -gt 0 ]]
                        then
                                echo "                                                                                                      "
                                echo "<<<<<<<<< The Requested User Account has been terminated on Local and Nis Master Server >>>>>>>>>>>   "
                                echo "                                                                                                      "
                                echo " Requested User Account : ${AD_Name}"
                                echo " Nis Master Server      : ${NisMaster}"
                                echo " Local Servers          :"
                                for (( i = 0 ; i < ${#UDLocalServerList[@]} ; i++ ))
                                do
                                        echo -e "\t$(($i+1)). ${UDLocalServerList[$i]}"
                                done
                        elif [[ "${CountOfIdentificationFoundOnLocal}" -gt 0 ]]
                        then
                                echo "                                                                                                      "
                                echo "<<<<<<<<< The Requested User Account has been terminated on Local Servers >>>>>>>>>>>   "
                                echo "                                                                                                      "
                                echo " Requested User Account : ${AD_Name}"
                                echo " Local Servers          :"
                                for (( i = 0 ; i < ${#UDLocalServerList[@]} ; i++ ))
                                do
                                        echo -e "\t$(($i+1)). ${UDLocalServerList[$i]}"
                                done
                        elif [[ "${CountOfIdentificationFoundOnSAMBA}" -gt 0 ]]
                        then
                                echo "                                                                                                      "
                                echo "<<<<<<<<< The Requested User Account has been terminated on Nis Master Server >>>>>>>>>>>             "
                                echo "                                                                                                      "
                                echo " Requested User Account : ${AD_Name}"
                                echo " Nis Master Server      : ${NisMaster}"
                        else
                        echo "                                                                                               "
                        fi
                fi
                #echo "Return Code : ${ReturnCode}"
        fi

        # User Termination Failed On Local Server
        if [[ "${MissedCountOnLocal}" -gt 0 ]]
        then
                echo "                                                             "
                echo "<<<<<<<<< User Termination Failed on Local Server >>>>>>>>>>>"
                echo "                                                             "
                echo "Number of local server where user termination failed : ${MissedCountOnLocal}"
                echo "                                                             "
                echo "We were not able to terminate a requested user on below server."
                for (( i = 0 ; i < ${#NUDServerList[@]} ; i++ ))
                do
                        echo -e "\t$(($i+1)). ${NUDServerList[$i]}"
                done
                echo "                                                             "
        fi

        # User Termination Failed On NisMaster Server
        if [[ "${MissedCountOnSAMBA}" -gt 0 ]]
        then
                echo "                                                                     "
                echo "<<<<<<<<< User Termination Failed on NIS Master Server >>>>>>>>>>>   "
                echo "                                                                     "
                echo "We were not able to terminate a requested user on below Nis Master Server."
                echo -e "\t1. ${NisMaster}"
        fi

        if [[ "${NISPushFailureCount}" -gt 0 ]]
        then
                echo "                                                                     "
                echo "<<<<<<<<< Remshell PUSH Failed on NIS Master Server >>>>>>>>>>>   "
                echo "                                                                     "
                echo "We were not able to terminate a requested user on below Nis Master Server."
                echo -e "\t1. ${NisMaster}"
        fi

elif [[ "${CountOfIdentificationFoundOnLocal}" -eq 0 && "${CountOfIdentificationFoundOnSAMBA}" -eq 0 ]]
then
        #Script for when the requested user is not found on local server and Nis Master Server.
        ReturnCode=2011 # WARNING CODE : the requested user is not found on local server and Nis Master Server.
        echo "                                                                                               "
        echo "<<<<<<<<< The Requested User Account is not found on Local and Nis Master Server >>>>>>>>>>>   "
        echo "                                                                                               "
elif [[ ( "${MissedCountOnSAMBA}" -eq 0 && "${NISPushFailureCount}" -eq 0 && "${CountOfIdentificationFoundOnSAMBA}" -gt 0 ) || ( "${MissedCountOnLocal}" -eq 0 && "${CountOfIdentificationFoundOnLocal}" -gt 0 ) ]]
then
        ReturnCode=2000
        if [[ "${CountOfIdentificationFoundOnLocal}" -gt 0 && "${CountOfIdentificationFoundOnSAMBA}" -gt 0 ]]
        then
                echo "                                                                                                      "
                echo "<<<<<<<<< The Requested User Account has been terminated on Local and Nis Master Server >>>>>>>>>>>   "
                echo "                                                                                                      "
                echo " Requested User Account : ${AD_Name}"
                echo " Nis Master Server      : ${NisMaster}"
                echo " Local Servers          :"
                for (( i = 0 ; i < ${#UDLocalServerList[@]} ; i++ ))
                do
                        echo -e "\t$(($i+1)). ${UDLocalServerList[$i]}"
                done
        elif [[ "${CountOfIdentificationFoundOnLocal}" -gt 0 ]]
        then
                echo "                                                                                                      "
                echo "<<<<<<<<< The Requested User Account has been terminated on Local Servers >>>>>>>>>>>   "
                echo "                                                                                                      "
                echo " Requested User Account : ${AD_Name}"
                echo " Local Servers          :"
                for (( i = 0 ; i < ${#UDLocalServerList[@]} ; i++ ))
                do
                        echo -e "\t$(($i+1)). ${UDLocalServerList[$i]}"
                done
        elif [[ "${CountOfIdentificationFoundOnSAMBA}" -gt 0 ]]
        then
                echo "                                                                                                      "
                echo "<<<<<<<<< The Requested User Account has been terminated on Nis Master Server >>>>>>>>>>>             "
                echo "                                                                                                      "
                echo " Requested User Account : ${AD_Name}"
                echo " Nis Master Server      : ${NisMaster}"
        else
                echo "                                                                                                      "
        fi
else
        ReturnCode=2012
fi

echo "Return Code : ${ReturnCode}"
echo "Report Generation Ended"