#!/bin/zsh
#set -x
############################################################################################
## oci_ocpu_scale.zsh
##
## PURPOSE: To change the OCI OCPU values of a ExaCC VM Cluster
##
## USAGE: oci_ocpu_scale.zsh <ocpu_value> 
##        It uses the INPUT_FILE=$HOME/Documents/scripts/config/oci_inputs.ctl file to process
##        the variables needed for this script
##        example of the contents of the control file
##
##        VM_CLUSTER_OCID:VM_OCID_VALUE
##        DEFAULT_OCPU :32
##        HIGHEST_OCPU_VAL:100
##
##        Modify the value of CONFIG_HOME=$HOME/Documents/scripts/config to your location
##
##        Use the lock file DO_NOT_CHANGE_OCPU_LOCK if you don't want the script to override the current 
##        OCPU value set in the VM Cluster
##
## SCRIPT PROCESS FLOW:
##
## OUTPUTS: Standard Output via command line execution.
##
## NOTIFICATION: Standard Output via command line execution.
##
## MODIFICATIONS:
##
##   Date        Name              Description
##   ----------  --------------    --------------------------------------
##   05/05/2021  Rene Antunez    Created
##
############################################################################################


################################################################################
# read_input_pars ()
# This function will read the oci_inputs.ctl in $HOME/Documents/scripts/config
################################################################################
read_input_pars()
{
INPUT_FILE=$CONFIG_HOME/oci_inputs.ctl
if [ ! -f ${INPUT_FILE} ];then
    echo "################################################################"
    echo "====>ERROR: File ${INPUT_FILE}"
    echo "                 is missing"
fi

while read input_file
do

LINE_START=`echo $input_file | cut -d: -f1`
case "$LINE_START" in
   VM_CLUSTER_OCID)         VM_CLUSTER_OCID=`echo $input_file |cut -d: -f2` ;;
   DEFAULT_OCPU)            DEFAULT_OCPU=`echo $input_file |cut -d: -f2` ;;
   HIGHEST_OCPU_VAL)        HIGHEST_OCPU_VAL=`echo $input_file |cut -d: -f2` ;
esac
done < ${INPUT_FILE}

export VM_CLUSTER_OCID DEFAULT_OCPU HIGHEST_OCPU_VAL
}

################################################################################
# validate_ocpu_values ()
# This function validates the minimum and maximum OCPU values that 
# the customer can scale up or down
################################################################################
validate_ocpu_values ()
{
if [ $1 -gt 1 -a $1 -le ${2} ];
then
   echo "====> New VM Cluster OCPU count of ${1} is : VALID"
else
   echo "====> New VM Cluster OCPU count of ${1} is : INVALID"
   echo "Valid OCPU Range is 2 - ${2} "
   echo "Exiting..."
   exit 0
fi
}

################################################################################
# get_ocpu_curr_value ()
# This function will read from OCI the current OCPU value
################################################################################
get_ocpu_curr_value()
{
#oci db vm-cluster get --vm-cluster-id ${VM_CLUSTER_OCID} | jq '.["data"]' | jq '.["cpus-enabled"]'
oci db vm-cluster get --vm-cluster-id ${VM_CLUSTER_OCID} | jq -r .data.\"cpus-enabled\"
}

################################################################################
# update_ocpu_curr_value ()
# This function will update from OCI the current OCPU value
################################################################################
update_ocpu_curr_value()
{
oci db vm-cluster update --cpu-core-count ${DEFAULT_OCPU} --vm-cluster-id ${VM_CLUSTER_OCID}
}


################################################################################
##  ------------------------------------------------------------------------  ##
##                        MAIN SCRIPT EXECUTION                               ##
##  ------------------------------------------------------------------------  ##
################################################################################
echo "************************************************************************"
echo "====>Script oci_ocpu_scale.zsh starting on" `date`
echo "************************************************************************"

################################################################################
# Set Variables Section
################################################################################
CONFIG_HOME=$HOME/Documents/scripts/config
export CONFIG_HOME
read_input_pars
DO_NOT_CHANGE_OCPU_LOCK="${CONFIG_HOME}/do_not_change_ocpu"
OVERRIDE_OCPU=$1
# Verify OCPU input
if [ -n "$OVERRIDE_OCPU" ]
then
   DEFAULT_OCPU=${OVERRIDE_OCPU}
fi

################################################################################
# Execution of Script
################################################################################
validate_ocpu_values ${DEFAULT_OCPU} ${HIGHEST_OCPU_VAL}
CURRENT_OCPU=$(get_ocpu_curr_value)
echo "====> Current VM Cluster OCPU Value is   : ${CURRENT_OCPU}"

if [[ -f "${DO_NOT_CHANGE_OCPU_LOCK}" ]]
then
   echo "====> Currently file ${DO_NOT_CHANGE_OCPU_LOCK} "
   echo "      is not allowing OCPU Modifications"
   echo "      Remove lock before re-execution"
   echo "      Exiting..."
   exit 1 
fi

if [[ ${DEFAULT_OCPU} -ne ${CURRENT_OCPU} ]]
then
   echo "====> Changing VM Cluster value to ${DEFAULT_OCPU} OCPUs"
   update_ocpu_curr_value
   CURRENT_OCPU=$(get_ocpu_curr_value)
   echo "====> Current VM Cluster OCPU Value is   : ${CURRENT_OCPU}"
else
   echo "====> Current VM Cluster OCPU Value is equal to ${DEFAULT_OCPU}" 
   echo "      Will not execute any scale up or scale down commands"
fi

echo "************************************************************************"
echo "====>Script oci_ocpu_scale.zsh ending on" `date`
echo "************************************************************************"
