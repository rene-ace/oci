#!/bin/bash
#set -x
################################################################################
# print_header_footer ()
# This function will print the header and footer of the script
################################################################################
print_header_footer ()
{
   echo " "
   echo "************************************************************************"
   echo "====> Script set_tenancy.sh is ${1} on" `date`
   echo "************************************************************************"
}

###############################################################################
# set_tenancy ()
# This function will set the tenancy in .oci
###############################################################################
set_tenancy()
{
         if [[ -f "${CI_CLI_RC_FILE_BUG}" ]]
         then
            OCI_CLI_RC_FILE=`cat ${TENANCIES_JSON_FILE} | jq -r --arg tenancy "$tenancy" '.[] | select(.tenancyName==$tenancy)| .ociConfigFileName'| tr -d \"`
            TENANCY_ID=`cat ${TENANCIES_JSON_FILE} | jq -r --arg tenancy "$tenancy" '.[] | select(.tenancyName==$tenancy)| .tenancyId'| tr -d \"`
            cp ~/.oci/${OCI_CLI_RC_FILE} ~/.oci/config
            echo "Selected Tenancy : "`oci iam tenancy get --tenancy-id $TENANCY_ID  | jq '.[].name' | tr -d \"`
            echo "Using OCI Config File : "$OCI_CLI_RC_FILE 
         else
            OCI_CLI_RC_FILE=`cat ${TENANCIES_JSON_FILE} | jq -r --arg tenancy "$tenancy" '.[] | select(.tenancyName==$tenancy)| .ociConfigFileName'| tr -d \"`
            TENANCY_ID=`cat ${TENANCIES_JSON_FILE} | jq -r --arg tenancy "$tenancy" '.[] | select(.tenancyName==$tenancy)| .tenancyId'| tr -d \"`
            echo "export OCI_CLI_RC_FILE=$OCI_CLI_RC_FILE" > ${CONFIG_HOME}/oci_set_env.sh

            echo "Selected Tenancy : "`oci iam tenancy get --tenancy-id $TENANCY_ID  | jq '.[].name' | tr -d \"`
            echo "Using OCI Config File : "$OCI_CLI_RC_FILE 

            chmod +x oci_set_env.sh
            exec $SHELL -l;
         fi
}
################################################################################
##  ------------------------------------------------------------------------  ##
##                        MAIN SCRIPT EXECUTION                               ##
##  ------------------------------------------------------------------------  ##
################################################################################
print_header_footer "starting"

################################################################################
# Set Variables Section
################################################################################
export SCRIPT_HOME=$HOME/scripts
export CONFIG_HOME=$SCRIPT_HOME/config
export LOG_HOME=$SCRIPT_HOME/logs

export CI_CLI_RC_FILE_BUG="${CONFIG_HOME}/ci_cli_rc_file_bug_file"
export TENANCIES_JSON_FILE=${CONFIG_HOME}/tenancies.json

PS3="Select a Tenancy : "
## Collect the tenancies in the array $tenancies
tenancies=(`cat ${TENANCIES_JSON_FILE} | jq '.[].tenancyName'| tr -d \"`)

################################################################################
# Execution of Script
################################################################################
## Enable extended globbing. This lets us use @(foo|bar) to
## match either 'foo' or 'bar'.
shopt -s extglob

## Start building the string to match against.
string="@(${tenancies[0]}"
## Add the rest of the tenancies to the string
for((i=1;i<${#tenancies[@]};i++))
do
    string+="|${tenancies[$i]}"
done
## Close the parenthesis. $string is now @(tenancies1|tenancies2|...|tenanciesN)
string+=")"

## Show the menu. This will list all tenancies and the string "Quit"
select tenancy in "${tenancies[@]}" "Quit"
do
    case $tenancy in
    ## If the choice is one of the tenancies (if it matches $string)
    $string)
        echo " "
        set_tenancy "$tenancy";
        print_header_footer "ending";
        break;
        ;;
    "Quit")
        echo " "
        echo "Exiting without changing current ~/.oci/config tenancy values"; 
        print_header_footer "ending";
        exit 0;;
    *)
        tenancy=""
        echo "Ooops - unknown choice $REPLY";
        echo "Please choose a number from 1 to $((${#tenancies[@]}+1))";;
    esac
done
exit 0
################################################################################
# End of Execution of Script
################################################################################
