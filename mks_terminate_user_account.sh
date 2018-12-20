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
# Last Modified On              : 12/20/2018 (MM/DD/YYYY)
#
# Latest Version                : 0.018
#########################################################################################################################

#Global Variables
nodeFile=/depot/MKS/Linux/sysadm/.usernodes
current_directory=$(dirname "$0")
isnodeFileExist=false
MAFServers=[]
MAFCount=0
identifiedUserCountOnLocal=0
identifiedUserCountOnSAMBA=0 
userTerminationFailedOnSAMBA=0
userTerminationFailedOnSAMBAServer=[]
userTerminationFailedOnLocal=0
userTerminationFailedOnLocalServer=[]
userTerminatedOnSAMBA=[]
userTerminatedCountOnSAMBA=0
userTerminatedOnServer=[]
userTerminatedCount=0
userPartOfSudoers=0
matchedSudoerServer=[]
countOfUserNodes=0
nodeIteration=0
notReachableNodeCount=0
notReachableNodes=[]
dmzPingFlag=-1
dmzSSHFlag=-1
isDMZJumpServerReachable="false"
reachableFromDMZJumpserver="false"
dmzJumpServer="mluser"
dmzWrapperScript="/root/MKS/UserDisableScript/mks_terminate_user_account_wrapper.sh"
adName=""
emailAddress=""

now=$(date +"%m/%d/%Y %H:%M:%S")
returnCode=2000

echo "<<<<<<<<< Unix Account Termination Script  >>>>>>>>>>>"
echo "                               "
echo "Execution Start Date Time of Terminate User Script : ${now}"
#######################################################################################
#<<<<<<<<<<<<<Determine and extract the required information from parameter.>>>>>>>>>>#
#######################################################################################
adName=$(echo "$1" | cut -d';' -f1 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//') # this code will split the parameter/data with the help of delimiter and extract adName of a requested user account
emailAddress=$(echo "$1" | cut -d';' -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//') # this code will split the parameter/data with the help of delimiter and extract email_address of a requested user account

echo "Name          : ${adName}"
echo "Email Address : ${emailAddress}"

######################################################################################
#<<<<<<<<<<<<<<<< Validating Parameter of the script - Begin >>>>>>>>>>>>>>>>>>>>>>>##
#Validated requested user account is not null or not and parameter count is 1 or not.#
######################################################################################
if [[ "$#" -ne 1 && "$1" == "" && ( "${adName}" != "" && "${emailAddress}" != "" ) ]]
then
  returnCode=4002 # ERROR CODE : Required Parameter Not Available.
  echo "                               "
  echo "ERROR : The AD Name/Email Address of an Unix Account is missing."
  echo "Return Code : ${returnCode}"
  exit 34
fi

####################################################################################
#<<<<<<<<<<<<<<<Validating requested user account is root or not.>>>>>>>>>>>>>>>>>>#
####################################################################################
if [[ "${adName}" == "root" && ( "${adName}" != "" || "${emailAddress}" != "" ) ]]
then
        returnCode=4005 # ERROR CODE : Requested AD Name is matching with root user account.
        echo "                               "
        echo "ERROR : The requested AD Name is Root Account, Either AD Name and emailAddress is missing. Automation will not handle root accounts."
        echo "Return Code : ${returnCode}"
        exit 34
fi

##################################################################################
#<<<<<<<<<<<<<<<< Validating Parameter of the script - End >>>>>>>>>>>>>>>>>>>>>>>
##################################################################################
if [[ ! -f "${nodeFile}" ]]
then
  returnCode=4001 # ERROR CODE : Node File Not Found
  echo "                               "
  echo "ERROR : The file was not found which contains nodes information"
  echo "Return Code : ${returnCode}"
  exit 34
fi

#############################################################################
#<<<<<<<<<<<<<<<<<< Function to get the current datetime >>>>>>>>>>>>>>>>>>>#
#############################################################################
getTimestamp()
{
   Date=`date +%m%d%Y.%H%M%S`
}


############################################################################
#<<< Connectivity check from DMZ Jumpserver to Target Server >>>>>>>>>>>>>##
############################################################################
checkConnectivityFromDMZJumpServer()
{
if [[ "${isDMZJumpServerReachable}" = "false" ]]
then
    #######################################################################################################################
    #<<<<<<<< valiating the connectivity to DMZ Jumpserver through ping command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>#
    #######################################################################################################################
    ping -c1 -W1 $dmzJumpServer > /dev/null 2>&1 && dmzPingFlag=0 || dmzPingFlag=-1
    #######################################################################################################################
    #<<<<<<<< valiating the connectivity to DMZ Jumpserver through ssh command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>>#
    #######################################################################################################################
    ssh "root@${dmzJumpServer}" "exit" > /dev/null 2>&1 && dmzSSHFlag=0 || dmzSSHFla
    if [[ "${dmzSSHFlag}" -eq 0 ]]
    then
      isDMZJumpServerReachable="true"
    fi
    
fi

if [[ "${isDMZJumpServerReachable}" = "true" ]]
then  
    ########################################################################################################################
    #<<<<<<<< valiating the connectivity through ping command (From MKS L & M Jumpserver > dmzJumpServer) >>>>>>>>>>>>>>>>>#
    ########################################################################################################################
    pingReport=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$servername" "ping"`
    [[ $(echo "${pingReport}" | cut -d':' -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//') = "true" ]] && pingFlag=0 || pingFlag=-1
    if [[ "${pingFlag}" -ne 0 ]]
    then
      pingReport=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$ip" "ping"`
      [[ $(echo "${pingReport}" | cut -d':' -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//') = "true" ]] && pingFlag=0 || pingFlag=-1
      if [[ "${pingFlag}" -eq 0 ]]
      then
        target=${ip}
        reachableFromDMZJumpserver="true"
      fi
    else
        target=${servername}
        reachableFromDMZJumpserver="true"
    fi

    #####################################################################################################
    #<<<<<<<< valiating the connectivity through ssh command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>>#
    #####################################################################################################
    sshReport=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$servername" "ssh"`
    [[ $(echo "${sshReport}" | cut -d':' -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//') = "true" ]] && sshFlag=0 || sshFlag=-1
    if [[ "${sshFlag}" -ne 0 ]]
    then
      sshReport=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$ip" "ssh"`
      [[ $(echo "${sshReport}" | cut -d':' -f2 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//') = "true" ]] && sshFlag=0 || sshFlag=-1
      if [[ "${sshFlag}" -eq 0 ]]
      then
        target=${ip}
        reachableFromDMZJumpserver="true"
      fi
    else
        target=${servername}
        reachableFromDMZJumpserver="true"
    fi
    
fi
}

terminate_user_account_from_dmzjumpserver()
{
  #echo "Terminate Account from DMZ Jumpserver"
  is_user_account_not_identified="false"
  is_multiple_user_account_identified="false"
  user_account_id=""
  user_account_name_on_local=""
  is_multiple_user_found_or_user_not_found=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/passwd'" | egrep -i "${adName}" | grep -iv root | awk -F: '{print $3}' | wc -l`
  if [[ "${is_multiple_user_found_or_user_not_found}" -ne 1 && "${emailAddress}" ]]
  then
    temp_is_multiple_user_found_or_user_not_found="${is_multiple_user_found_or_user_not_found}"
    is_multiple_user_found_or_user_not_found=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/passwd'" | grep -i ${emailAddress} | grep -iv root | awk -F: '{print $3}' | wc -l`
    if [[ "${is_multiple_user_found_or_user_not_found}" -gt 1 || "${temp_is_multiple_user_found_or_user_not_found}" -gt 1 ]]
    then
      is_multiple_user_account_identified="true"
    elif [[ "${is_multiple_user_found_or_user_not_found}" -eq 0 ]]
    then
      is_user_account_not_identified="true"
    else
      user_account_id=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/passwd'" | grep -i ${emailAddress} | grep -iv root | awk -F: '{print $3}'`
    fi
  elif [[ "${is_multiple_user_found_or_user_not_found}" -ne 1 && ( ! "${emailAddress}" ) ]]
  then
    if [[ "${is_multiple_user_found_or_user_not_found}" -gt 1 ]]
    then
      is_multiple_user_account_identified="true"
    else
      is_user_account_not_identified="true"
    fi
  else
    #user account identified with the help of user adName
    user_account_id=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/passwd'" | egrep -i "${adName}" | grep -iv root | awk -F: '{print $3}'`
  fi
  
  if [[ "${is_multiple_user_account_identified}" = "true" ]]
  then
    MAFServers[${MAFCount}]="${target}"
    MAFCount=$(( $MAFCount + 1 ))
  fi

  # Is user is part of a samba application
  user_name_on_samba=""
  is_samba_user="false"
  lc_samba=$(echo "${samba}" | tr '[:upper:]' '[:lower:]')
  #echo "SAMBA STATUS : ${lc_samba}"
  if [[ (! ( "${is_multiple_user_account_identified}" = "true" || "${is_user_account_not_identified}" = "true" ) ) && "${lc_samba}" = "yes" ]]
  then
    echo "checking whether the user is a part of samba application or not..."
    is_samba_user_identified=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'pdbedit -L'" | awk -F: -v user_id="$user_account_id" '$2==user_id { print $0 }' | wc -l`
    if [[ "${is_samba_user_identified}" -eq 1 ]]
    then
      is_samba_user="true"
      user_name_on_samba=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'pdbedit -L'" | awk -F: -v user_id="$user_account_id" '$2==user_id { print $0 }' | cut -d: -f1 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
    fi
  fi
 : << 'Comment2' 
  #Proceeding with further execution.
  echo "Is Multiple User Found : ${is_multiple_user_account_identified}"
  echo "Is User Not Found : ${is_user_account_not_identified}"
  echo "Is SAMBA User : ${is_samba_user}"
  echo "User ID : ${user_account_id}"
Comment2

  #Trim before and after.
  user_account_id=$(echo "${user_account_id}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
  if [[ "${user_account_id}" != "" && "${user_account_id}" -ne 0 && "${is_user_account_not_identified}" = "false" && "${is_multiple_user_account_identified}" = "false" ]]
  then
    # Terminate and validate the samba user is terminated or not
    if [[ "${is_samba_user}" = "true" ]]
    then
      #echo "remove user on samba application."
      ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'smbpasswd -x $user_name_on_samba > /dev/null 2>&1'"
      is_samba_user_terminated=`ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'pdbedit -L'" | awk -F: -v user_id="$user_account_id" '$2==user_id { print $0 }' | wc -l`
      if [[ "${is_samba_user_terminated}" -eq 0 ]]
      then
        #echo "The requested user (${adName}) has been terminated on samba application."
        userTerminatedOnSAMBA[${userTerminatedCountOnSAMBA}]="${servername}"
        userTerminatedCountOnSAMBA=$(($userTerminatedCountOnSAMBA + 1))
      else
        #echo "unable to terminate a requested user on samba application."
        userTerminationFailedOnSAMBAServer[${userTerminationFailedOnSAMBA}]="${servername}"
        userTerminationFailedOnSAMBA=$(($userTerminatedCountOnSAMBA + 1))
      fi
    fi
    user_account_name_on_local=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/passwd'" | awk -F: -v user_id="$user_account_id" '$3==user_id { print $0 }' | cut -d: -f1 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
    ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'userdel -r "$user_account_name_on_local" > /dev/null 2>&1'"
    is_user_terminated_on_os_level=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/passwd'" | awk -F: -v user_id="$user_account_id" '$3==user_id { print $0 }' | wc -l)
    if [[ "${is_user_terminated_on_os_level}" -eq 0 ]]
    then
      #echo "The requested user (${adName}) has been terminated on OS Level."
      userTerminatedOnServer[${userTerminatedCount}]="${servername}"
      userTerminatedCount=$(($userTerminatedCount + 1))

      #Verify user is a part of /etc/sudoers (or, /etc/sudoers.d/*) file
      #[ -e /etc/sudoers ] && echo "Found" || echo "Not found"
      is_sudoer_exist=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'[ -e /etc/sudoers ] && echo "exist" || echo "not exist"'" | grep -v not | wc -l)
      is_sudoer_dir_exist=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'[ -d /etc/sudoers.d ] && echo "exist" || echo "not exist"'" | grep -v not | wc -l)
      if [[ "${is_sudoer_exist}" -gt 0 && "${is_sudoer_dir_exist}" -gt 0 ]]
      then
        echo "sudoers and sudoers.d exist."
        is_user_exist_on_sudoers_file=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/sudoers'" | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        is_user_exist_on_sudoers_dir=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/sudoers.d/* 2> /temp'" | grep -v 'No such file or directory' | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        if [[ "${is_user_exist_on_sudoers_file}" -gt 0 || "${is_user_exist_on_sudoers_dir}" -gt 0 ]]
        then
          matchedSudoerServer[${userPartOfSudoers}]="${servername}"
          userPartOfSudoers=$(($userPartOfSudoers + 1))
        fi
      elif [[ "${is_sudoer_exist}" -gt 0 ]]
      then
        echo "sudoers exist."
        is_user_exist_on_sudoers_file=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/sudoers'" | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        if [[ "${is_user_exist_on_sudoers_file}" -gt 0 ]]
        then
          matchedSudoerServer[${userPartOfSudoers}]="${servername}"
          userPartOfSudoers=$(($userPartOfSudoers + 1))
        fi
      elif [[ "${is_sudoer_dir_exist}" -gt 0 ]]
      then
        echo "sudoers.d exist."
        is_user_exist_on_sudoers_dir=$(ssh "root@${dmzJumpServer}" 'bash -s' < "${current_directory}/check_connectivity_from_dmz_to_targetnode.sh" "$target" "remote_cmd_execution" "'cat /etc/sudoers.d/* 2> /temp'" | grep -v 'No such file or directory' | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        if [[ "${is_user_exist_on_sudoers_dir}" -gt 0 ]]
        then
          matchedSudoerServer[${userPartOfSudoers}]="${servername}"
          userPartOfSudoers=$(($userPartOfSudoers + 1))
        fi
      fi
   else
      #echo "unable to terminate a requested user on samba application."
      userTerminationFailedOnLocalServer[${userTerminationFailedOnLocal}]="${servername}"
      userTerminationFailedOnLocal=$(($userTerminationFailedOnLocal + 1))
    fi
  fi
}

terminate_user_account_from_jumpserver()
{
  #echo "Terminate Account from L&M Jumpserver"
  is_user_account_not_identified="false"
  is_multiple_user_account_identified="false"
  user_account_id=""
  user_account_name_on_local=""
  ssh ${target} cat /etc/passwd | egrep -i "${adName}" | grep -iv root | awk -F: '{print $3}' | wc -l
  is_multiple_user_found_or_user_not_found=`ssh ${target} cat /etc/passwd | egrep -i "${adName}" | grep -iv root | awk -F: '{print $3}' | wc -l`
  if [[ "${is_multiple_user_found_or_user_not_found}" -ne 1 && "${emailAddress}" ]]
  then
    temp_is_multiple_user_found_or_user_not_found="${is_multiple_user_found_or_user_not_found}"
    is_multiple_user_found_or_user_not_found=`ssh ${target} cat /etc/passwd | grep -i ${emailAddress} | grep -iv root | awk -F: '{print $3}' | wc -l`
    if [[ "${is_multiple_user_found_or_user_not_found}" -gt 1 || "${temp_is_multiple_user_found_or_user_not_found}" -gt 1 ]]
    then
      is_multiple_user_account_identified="true"
    elif [[ "${is_multiple_user_found_or_user_not_found}" -eq 0 ]]
    then
      is_user_account_not_identified="true"
    else
      user_account_id=`ssh ${target} cat /etc/passwd | grep -i ${emailAddress} | grep -iv root | awk -F: '{print $3}'`
    fi
  elif [[ "${is_multiple_user_found_or_user_not_found}" -ne 1 && ( ! "${emailAddress}" ) ]]
  then
    if [[ "${is_multiple_user_found_or_user_not_found}" -gt 1 ]]
    then
      is_multiple_user_account_identified="true"
    else
      is_user_account_not_identified="true"
    fi
  else
    #user account identified with the help of user adName
    user_account_id=`ssh ${target} cat /etc/passwd | egrep -i "${adName}" | grep -iv root | awk -F: '{print $3}'`
  fi
  
  [[ "${is_multiple_user_account_identified}" = "true" ]] && echo "MAF : true" || echo "MAF : false"

  if [[ "${is_multiple_user_account_identified}" = "true" ]]
  then
    echo "Multiple user account found."
    MAFServers[${MAFCount}]="${target}"
    MAFCount=$(( $MAFCount + 1 ))
  fi

  # Is user is part of a samba application
  user_name_on_samba=""
  is_samba_user="false"
  lc_samba=$(echo "${samba}" | tr '[:upper:]' '[:lower:]')
#  echo "SAMBA STATUS : ${lc_samba}"
  if [[ (! ( "${is_multiple_user_account_identified}" = "true" || "${is_user_account_not_identified}" = "true" ) ) && "${lc_samba}" = "yes" ]]
  then
    echo "checking whether the user is a part of samba application or not..."
    is_samba_user_identified=`ssh ${target} pdbedit -L | awk -F: -v user_id="$user_account_id" '$2==user_id { print $0 }' | wc -l`
    if [[ "${is_samba_user_identified}" -eq 1 ]]
    then
      is_samba_user="true"
      user_name_on_samba=$(ssh ${target} pdbedit -L | awk -F: -v user_id="$user_account_id" '$2==user_id { print $0 }' | cut -d: -f1 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
    fi
  fi

  #Proceeding with further execution.
: << 'Comment1'
  echo "Is Multiple User Found : ${is_multiple_user_account_identified}"
  echo "Is User Not Found : ${is_user_account_not_identified}"
  echo "Is SAMBA User : ${is_samba_user}"
  echo "User ID : ${user_account_id}"
Comment1

  #Trim before and after.
  user_account_id=$(echo "${user_account_id}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
  if [[ "${user_account_id}" != "" && "${user_account_id}" -ne 0 && "${is_user_account_not_identified}" = "false" && "${is_multiple_user_account_identified}" = "false" ]]
  then
    # Terminate and validate the samba user is terminated or not
    if [[ "${is_samba_user}" = "true" ]]
    then
      #echo "remove user on samba application."
      ssh root@$target smbpasswd -x $user_name_on_samba > /dev/null 2>&1
      is_samba_user_terminated=`ssh ${target} pdbedit -L | awk -F: -v user_id="$user_account_id" '$2==user_id { print $0 }' | wc -l`
      if [[ "${is_samba_user_terminated}" -eq 0 ]]
      then
        #echo "The requested user (${adName}) has been terminated on samba application."
        userTerminatedOnSAMBA[${userTerminatedCountOnSAMBA}]="${servername}"
        userTerminatedCountOnSAMBA=$(($userTerminatedCountOnSAMBA + 1))
      else
        #echo "unable to terminate a requested user on samba application."
        userTerminationFailedOnSAMBAServer[${userTerminationFailedOnSAMBA}]="${servername}"
        userTerminationFailedOnSAMBA=$(($userTerminatedCountOnSAMBA + 1))
      fi
    fi
    user_account_name_on_local=$(ssh ${target} cat /etc/passwd | awk -F: -v user_id="$user_account_id" '$3==user_id { print $0 }' | cut -d: -f1 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
    ssh root@$target userdel -r "$user_account_name_on_local" > /dev/null 2>&1
    is_user_terminated_on_os_level=$(ssh ${target} cat /etc/passwd | awk -F: -v user_id="$user_account_id" '$3==user_id { print $0 }' | wc -l)
    if [[ "${is_user_terminated_on_os_level}" -eq 0 ]]
    then
      #echo "The requested user (${adName}) has been terminated on OS Level."
      userTerminatedOnServer[${userTerminatedCount}]="${servername}"
      userTerminatedCount=$(($userTerminatedCount + 1))
      # validate a user is part of sudoer file.
      is_sudoer_exist=$(ssh ${target} '[ -e /etc/sudoers ] && echo "exist" || echo "not exist"' | grep -v not | wc -l )
      is_sudoer_dir_exist=$(ssh ${target} '[ -d /etc/sudoers.d ] && echo "exist" || echo "not exist"' | grep -v not | wc -l )
      if [[ "${is_sudoer_exist}" -gt 0 && "${is_sudoer_dir_exist}" -gt 0 ]]
      then
        echo "sudoers and sudoers.d exist."
        is_user_exist_on_sudoers_file=$(ssh ${target} 'cat /etc/sudoers' | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        is_user_exist_on_sudoers_dir=$(ssh ${target} 'cat /etc/sudoers.d/* 2> /temp' | grep -v 'No such file or directory' | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        if [[ "${is_user_exist_on_sudoers_file}" -gt 0 || "${is_user_exist_on_sudoers_dir}" -gt 0 ]]
        then
          matchedSudoerServer[${userPartOfSudoers}]="${servername}"
          userPartOfSudoers=$(($userPartOfSudoers + 1))
        fi
      elif [[ "${is_sudoer_exist}" -gt 0 ]]
      then
        echo "sudoers exist."
        is_user_exist_on_sudoers_file=$(ssh ${target} 'cat /etc/sudoers' | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        if [[ "${is_user_exist_on_sudoers_file}" -gt 0 ]]
        then
          matchedSudoerServer[${userPartOfSudoers}]="${servername}"
          userPartOfSudoers=$(($userPartOfSudoers + 1))
        fi
      elif [[ "${is_sudoer_dir_exist}" -gt 0 ]]
      then
        echo "sudoers.d exist."
        is_user_exist_on_sudoers_dir=$(ssh ${target} 'cat /etc/sudoers.d/* 2> /temp' | grep -v 'No such file or directory' | grep -v '^#' | grep -i "$user_account_name_on_local" | wc -l)
        if [[ "${is_user_exist_on_sudoers_dir}" -gt 0 ]]
        then
          matchedSudoerServer[${userPartOfSudoers}]="${servername}"
          userPartOfSudoers=$(($userPartOfSudoers + 1))
        fi
      fi
   else
      #echo "unable to terminate a requested user on samba application."
      userTerminationFailedOnLocalServer[${userTerminationFailedOnLocal}]="${servername}"
      userTerminationFailedOnLocal=$(($userTerminationFailedOnLocal + 1))
    fi
  fi
}


countOfUserNodes=$(cat "${nodeFile}" | grep -v '^#' | wc -l)
echo " "
echo "Number of servers : ${countOfUserNodes}"
readarray -t lines < ${nodeFile}
for line in "${lines[@]}"; do

    ################################################################################
    #<<<<<<<<<<<<<<<<<<<check line is already commented or not>>>>>>>>>>>>>>>>>>>>>#
    ################################################################################
    lineSkipRequired=$(echo "${line}" | grep -e '^#' | wc -l)
    if [[ "${lineSkipRequired}" -eq 0 ]]
    then
      #split required data from fields.
      servername=$(echo "${line}" | cut -d, -f1)
      ip=$(echo "${line}" | cut -d, -f2)
      domain=$(echo "${line}" | cut -d, -f3)
      dmz=$(echo "${line}" | cut -d, -f4)
      samba=$(echo "${line}" | cut -d, -f5)

      # trim our node records
      servername=$(echo "${servername}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
      ip=$(echo "${ip}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
      domain=$(echo "${domain}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
      dmz=$(echo "${dmz}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
      samba=$(echo "${samba}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
      
      #Local variable
      target=""
      sshFlag=-1
      pingFlag=-1
      reachableFromDMZJumpserver="false"

      echo "servername=${servername}  ipaddress=${ip} domain=${domain} dmz(yes/no)=${dmz} samba(yes/no)=${samba}"

      nodeIteration=$(($nodeIteration + 1))
      echo "  Checking ${nodeIteration} of ${countOfUserNodes} hosts"

      lc_dmz=$(echo "${dmz}" | tr '[:upper:]' '[:lower:]')
      #echo "dmz status (in lowercase) : ${lc_dmz}"
      #<<<<<<<<<<<<<<<<<< DMZ & Connectivity Validation Block >>>>>>>>>>>>>>>>>>>>>>#
      if [[ "${lc_dmz}" = "yes" ]]
      then
        # servers under dmz
        echo "    ${servername} is in dmz (${dmzJumpServer})."
        checkConnectivityFromDMZJumpServer
      else
        # servers not under dmz
        # echo "${servername} is not in dmz."

        #####################################################################################################
        #<<<<<<<< valiating the connectivity through ping command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>#
        #####################################################################################################
        ping -c1 -W1 $servername > /dev/null 2>&1 && pingFlag=0 || pingFlag=-1
        if [[ "${pingFlag}" -ne 0 ]]
        then
          ping -c1 -W1 $ip > /dev/null 2>&1 && pingFlag=0 || pingFlag=-1
          if [[ "${pingFlag}" -eq 0 ]]
          then
            target=${ip}
          fi
        else
            target=${servername}
        fi

        #####################################################################################################
        #<<<<<<<< valiating the connectivity through ssh command (From MKS L & M Jumpserver) >>>>>>>>>>>>>>>#
        #####################################################################################################
        ssh "root@${servername}" "exit" > /dev/null 2>&1 && sshFlag=0 || sshFlag=-1
        if [[ "${sshFlag}" -ne 0 ]]
        then
          ssh "root@${ip}" "exit" > /dev/null 2>&1 && sshFlag=0 || sshFlag=-1
          if [[ "${sshFlag}" -eq 0 ]]
          then
            target=${ip}
          fi
        else
            target=${servername}
        fi
        
        # Try from DMZ server - Block
        if [[ "${sshFlag}" -ne 0 ]]
        then
          checkConnectivityFromDMZJumpServer
        fi
        # Try from DMZ server - Block
      fi
      #<<<<<<<<<<<<<<<<<< DMZ & Connectivity Validation Block >>>>>>>>>>>>>>>>>>>>>>#
      
      
      [[ "${pingFlag}" -ne 0 ]] && echo "    Server Ping Status : Down" || echo "    Server Ping  Status : Up"
      [[ "${sshFlag}" -ne 0 ]] && echo "    Server SSH  Status : Down" || echo "    Server SSH  Status : Up"

      
      #<<<<<<<<<<<<<<<<<<<<<<< Level 2 Action - Check user and terminate user on target servers (Block) >>>>>>>>>>>>>>>>>>>>>>#
      if [[ "${sshFlag}" -ne 0 ]]
      then
          notReachableNodes[${notReachableNodeCount}]=${servername}
          notReachableNodeCount=$(($notReachableNodeCount + 1))
      else
          if [[ "${reachableFromDMZJumpserver}" = "true" ]]
          then
            terminate_user_account_from_dmzjumpserver
          else
            terminate_user_account_from_jumpserver
          fi
      fi
      #<<<<<<<<<<<<<<<<<<<<<<< Level 2 Action - Check user and terminate user on target servers (Block) >>>>>>>>>>>>>>>>>>>>>>#
    fi
done


#Report Generation - Block Start
echo "Report Generation Started"
if [[ "${userTerminationFailedOnSAMBA}" -gt 0 || "${userTerminationFailedOnLocal}" -gt 0 || "${notReachableNodeCount}" -gt 0 || "${MAFCount}" -gt 0 || "${userPartOfSudoers}" -gt 0 ]]
then
  ReturnCode=2010
  # Report Unreachable Server
  if [[ "${notReachableNodeCount}" -gt 0 ]]
  then
    echo -e "\r                                           \r"
    echo -e "\r<<<<<<<<< NOT REACHABLE SERVERS >>>>>>>>>>>\r"
    echo -e "\r                                           \r"
    echo -e "\rNumber of not reachable nodes : ${notReachableNodeCount}\r"
    echo -e "\r                                           \r"
    echo -e "\rWe were not able to reach the below servers\r"
    #notReachableNodes
    for (( i = 0 ; i < ${#notReachableNodes[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${notReachableNodes[$i]}\r"
    done
  fi
   
  # Report SAMBA Failure
  if [[ "${userTerminationFailedOnSAMBA}" -gt 0 ]]
  then
    echo -e "\r                                           \r"
    echo -e "\r<<<<<<<<< User Termination Failed On SAMBA Application >>>>>>>>>>>\r"
    echo -e "\r                                           \r"
    echo -e "\rNumber user termination failed on SAMBA : ${userTerminationFailedOnSAMBA}\r"
    echo -e "\r                                           \r"
    echo -e "\rWe were not able to terminate the users on below SAMBA server\r"
    #notReachableNodes
    for (( i = 0 ; i < ${#userTerminationFailedOnSAMBAServer[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${userTerminationFailedOnSAMBAServer[$i]}\r"
    done
  fi
  # Report User DEL Failure on OS Level
  if [[ "${userTerminationFailedOnLocal}" -gt 0 ]]
  then
    echo -e "\r                                           \r"
    echo -e "\r<<<<<<<<< User Termination Failed On OS Level >>>>>>>>>>>\r"
    echo -e "\r                                           \r"
    echo -e "\rNumber user termination failed on OS Level : ${userTerminationFailedOnLocal}\r"
    echo -e "\r                                           \r"
    echo -e "\rWe were not able to terminate a user account on below server at OS Level.\r"
    #notReachableNodes
    for (( i = 0 ; i < ${#userTerminationFailedOnLocalServer[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${userTerminationFailedOnLocalServer[$i]}\r"
    done
  fi

  # Report the servers where the user was a part of sudoers file.
  if [[ "${userPartOfSudoers}" -gt 0 ]]
  then
    echo -e "\r                                                                 \r"
    echo -e "\r<<<<<<<<< User is part of sudoers file >>>>>>>>>>>>>>>>>>>>>>\r"
    echo -e "\r                                                                 \r"
    echo -e "\rTotal Server where user account identified on sudoers list : ${userPartOfSudoers}\r"
    echo -e "\r                                                                 \r"
    echo -e "\rThe user account is a part of the sudoer list on below servers.     \r"
    for (( i = 0 ; i < ${#matchedSudoerServer[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${matchedSudoerServer[$i]}\r"
    done
  fi

  # Report MAF Identified
  if [[ "${MAFCount}" -gt 0 ]]
  then
    echo -e "\r                                                                 \r"
    echo -e "\r<<<<<<<<< Multiple user account identified >>>>>>>>>>>>>>>>>>>>>>\r"
    echo -e "\r                                                                 \r"
    echo -e "\rTotal Server where Multiple user account identified : ${MAFCount}\r"
    echo -e "\r                                                                 \r"
    echo -e "\rMultiple user accounts has been identified on below servers.     \r"
    #notReachableNodes
    for (( i = 0 ; i < ${#MAFServers[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${MAFServers[$i]}\r"
    done
  fi
  # User Terminated On SAMBA Application
  if [[ "${userTerminatedCountOnSAMBA}" -gt 0 ]]
  then
    echo -e "\r                                                                 \r"
    echo -e "\r<<<<<<<<< User Account Terminated On SAMBA >>>>>>>>>>>>>>>>>>>>>>\r"
    echo -e "\r                                                                 \r"
    echo -e "\rTotal Server where user account terminated on SAMBA : ${userTerminatedCountOnSAMBA}\r"
    echo -e "\r                                                                 \r"
    echo -e "\rWe were terminated user account in SAMBA Application on below servers.\r"
    for (( i = 0 ; i < ${#userTerminatedOnSAMBA[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${userTerminatedOnSAMBA[$i]}\r"
    done
  fi
  # User Terminated On OS Level
  if [[ "${userTerminatedCount}" -gt 0 ]]
  then
    echo -e "\r                                                                 \r"
    echo -e "\r<<<<<<<<< User Account Terminated On OS Level >>>>>>>>>>>>>>>>>>>>>>\r"
    echo -e "\r                                                                 \r"
    echo -e "\rTotal Server where user account terminated on OS Level : ${userTerminatedCount}\r"
    echo -e "\r                                                                 \r"
    echo -e "\rWe were terminated user account in OS Level on below servers.\r"
    for (( i = 0 ; i < ${#userTerminatedOnServer[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${userTerminatedOnServer[$i]}\r"
    done
  fi
elif [[ "${userTerminatedCountOnSAMBA}" -eq 0 && "${userTerminatedCount}" -eq 0 ]]
then
  ReturnCode=2011
  echo "The requested user account is not idenified on any of our unix servers."
elif [[ ${userTerminatedCountOnSAMBA} -gt 0 || ${userTerminatedCount} -gt 0 ]]
then
  ReturnCode=2000
  # User Terminated On SAMBA Application
  if [[ "${userTerminatedCountOnSAMBA}" -gt 0 ]]
  then
    echo -e "\r                                                                 \r"
    echo -e "\r<<<<<<<<< User Account Terminated On SAMBA >>>>>>>>>>>>>>>>>>>>>>\r"
    echo -e "\r                                                                 \r"
    echo -e "\rTotal Server where user account terminated on SAMBA : ${userTerminatedCountOnSAMBA}\r"
    echo -e "\r                                                                 \r"
    echo -e "\rWe were terminated user account in SAMBA Application on below servers.\r"
    for (( i = 0 ; i < ${#userTerminatedOnSAMBA[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${userTerminatedOnSAMBA[$i]}\r"
    done
  fi
  # User Terminated On OS Level
  if [[ "${userTerminatedCount}" -gt 0 ]]
  then
    echo -e "\r                                                                 \r"
    echo -e "\r<<<<<<<<< User Account Terminated On OS Level >>>>>>>>>>>>>>>>>>>>>>\r"
    echo -e "\r                                                                 \r"
    echo -e "\rTotal Server where user account terminated on OS Level : ${userTerminatedCount}\r"
    echo -e "\r                                                                 \r"
    echo -e "\rWe were terminated user account in OS Level on below servers.\r"
    for (( i = 0 ; i < ${#userTerminatedOnServer[@]} ; i++ ))
    do
      echo -e "\r\t$(($i+1)). ${userTerminatedOnServer[$i]}\r"
    done
  fi
else
  ReturnCode=2012
fi
echo "Return Code : ${ReturnCode}"
echo "Report Generation Ended"
#Report Generation - Block Start