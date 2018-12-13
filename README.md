# user termination script

This script will help unix administrator to terminate their unix user accounts and SAMBA application users on unix environment. 

This script will allow an unix administrator to execute it from unix jumpserver to target.

# prerequisite :-

Supported Operating System : RedHat, OpenSUSE, AIX and Ubuntu.

Administrator should enable passwordless connection between jumpserver to target server/node.

# script output :-

[root@netbackuplinuxmaster UserDisableScript]# sh +x ./mks_terminate_user_account.sh 'xxxxxxx ; xxxxxxx.xxxx@gmail.com'

<<<<<<<<< Unix Account Termination Script  >>>>>>>>>>>

Execution Start Date Time of Terminate User Script : 12/13/2018 14:06:40

Name          : xxxxxxx

Email Address : xxxxxxx.xxxx@gmail.com

Number of servers : 2

servername=mluser  ipaddress=10.129.3.9 domain=MKS dmz(yes/no)=NO samba(yes/no)=YES
  
  Checking 1 of 2 hosts
    
    Server Ping  Status : Up
    
    Server SSH  Status : Up

checking whether the user is a part of samba application or not...

servername=autolinrhel63  ipaddress=10.129.3.37 domain=MKS dmz(yes/no)=YES samba(yes/no)=NO
  
  Checking 2 of 2 hosts
    
    autolinrhel63 is in dmz (mluser).
    
    Server Ping  Status : Up
    
    Server SSH  Status : Up

Report Generation Started

<<<<<<<<< User Account Terminated On SAMBA >>>>>>>>>>>>>>>>>>>>>>

Total Server where user account terminated on SAMBA : 1

We were terminated user account in SAMBA Application on below servers.
        
        1. mluser

<<<<<<<<< User Account Terminated On OS Level >>>>>>>>>>>>>>>>>>>>>>

Total Server where user account terminated on OS Level : 2

We were terminated user account in OS Level on below servers.
        
        1. mluser
        
        2. autolinrhel63

Return Code : 2000

Report Generation Ended
