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
## SCRIPT PROCESS FLOW:
##
## OUTPUTS: Standard Output via command line execution.
##
## NOTIFICATION: Standard Output via command line execution.
##
## MODIFICATIONS:
##
##   Date          Name              Description
##   (DD/MM/YYYY)
##   ----------    --------------    --------------------------------------
##   11/04/2021    Rene Antunez      Created
##
############################################################################################


################################################################################
# usage ()
# This function will show the usage of the script
################################################################################

usage()
{
  echo "Usage: oci_ocpu_scale.sh [ -s | --status ] 
                         [ -o | --scale_ocpu ]
                         [ -i | --ocid ]" 
  echo ""
  echo " e.g.
         ./oci_ocpu_scale.sh -i ocid1.vmcluster.oc1.ca-toronto-1.aaaaaaaabbbbbbddddddd -o 16"
  echo  ""
  echo "########################################################"
  echo "Note 1:    [ -i | --ocid ] is a mandatory value"
  echo ""
  echo "Note 2: If [ -o | --scale_ocpu ] is empty,"
  echo "        It will use the values of config/oci_inputs.ctl"
  echo ""
  echo "Note 3: File config/do_not_change_ocpu will not allow a change of OCPUs"
  echo "########################################################"

  exit 1
}

################################################################################
# parse_arguments ()
# This function will parse the arguments passed to the script
################################################################################
parse_arguments()
{ 

# make args an array, not a string
args=( )

# replace long arguments
for arg; do
    case "$arg" in
        --status)         args+=( -s ) ;;
        --scale_ocpu)     args+=( -o ) ;;
        --ocid)           args+=( -i ) ;;
        *)                args+=( "$arg" ) ;;
    esac
done

#printf 'args before update : '; printf '%q ' "$@"; echo
set -- "${args[@]}"
#printf 'args after update  : '; printf '%q ' "$@"; echo

while getopts "so:i:" OPTION; do
    : "$OPTION" "$OPTARG"
#    echo "optarg : $OPTARG"
    case $OPTION in
    s)  usage; ;;
    o)  DEFAULT_OCPU=("$OPTARG");;
    i)  VM_CLUSTER_OCID="$OPTARG";;
    esac
done

if [ -z "$VM_CLUSTER_OCID" ]; then
   usage
fi
}


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
    exit 1
fi

while read input_file
do

LINE_START=`echo $input_file | cut -d: -f1`
case "$LINE_START" in
#   VM_CLUSTER_OCID)         VM_CLUSTER_OCID=`echo $input_file |cut -d: -f2` ;;
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
   exit 1
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
# oci db vm-cluster update --cpu-core-count ${OCPU_VAL} --vm-cluster-id ${VM_CLUSTER_OCID} --wait-for-state AVAILABLE | jq -r .data.\"display-name\"
echo "db vm-cluster update --cpu-core-count ${OCPU_VAL} --vm-cluster-id ${VM_CLUSTER_OCID} --wait-for-state AVAILABLE | jq -r .data.display-name"
}


################################################################################
##  ------------------------------------------------------------------------  ##
##                        MAIN SCRIPT EXECUTION                               ##
##  ------------------------------------------------------------------------  ##
################################################################################
echo "************************************************************************"
echo "====>Script oci_ocpu_scale.sh starting on" `date`
echo "************************************************************************"

################################################################################
# Beginning of parsing arguments
################################################################################
# make args an array, not a string
args=( )

# replace long arguments
for arg; do
    case "$arg" in
        --status)         args+=( -s ) ;;
        --scale_ocpu)     args+=( -o ) ;;
        --ocid)           args+=( -i ) ;;
        *)                args+=( "$arg" ) ;;
    esac
done

#printf 'args before update : '; printf '%q ' "$@"; echo
set -- "${args[@]}"
#printf 'args after update  : '; printf '%q ' "$@"; echo

while getopts "so:i:" OPTION; do
    : "$OPTION" "$OPTARG"
#    echo "optarg : $OPTARG"
    case $OPTION in
    s)  STATUS="true" ;;
    o)  SCALE_OCPU_VAL=("$OPTARG");;
    i)  VM_CLUSTER_OCID="$OPTARG";;
    esac
done

################################################################################
#  End of parsing arguments
#  This function will parse the arguments passed to the script
################################################################################

################################################################################
# Set Variables Section
################################################################################
CONFIG_HOME=$HOME/Documents/scripts/config
export CONFIG_HOME
read_input_pars
DO_NOT_CHANGE_OCPU_LOCK="${CONFIG_HOME}/do_not_change_ocpu"

if [ -z "$VM_CLUSTER_OCID" ]; then
   usage
fi

if [ -n "$SCALE_OCPU_VAL" ]
then
   OCPU_VAL=${SCALE_OCPU_VAL}
else
   OCPU_VAL=${DEFAULT_OCPU}
fi
export OCPU_VAL
export VM_CLUSTER_OCID

################################################################################
# Execution of Script
################################################################################
CURRENT_OCPU=$(get_ocpu_curr_value)

echo "====> Current VM Cluster OCPU Value is   : ${CURRENT_OCPU}"

if [ "${STATUS}" = "true" ]; then
   exit 0
fi

validate_ocpu_values ${OCPU_VAL} ${HIGHEST_OCPU_VAL}

if [[ -f "${DO_NOT_CHANGE_OCPU_LOCK}" ]]
   then
      echo "====> Currently file ${DO_NOT_CHANGE_OCPU_LOCK} "
      echo "      is not allowing OCPU Modifications"
      echo "      Remove lock before re-execution"
      echo "      Exiting..."
      exit 1 
   fi

   if [[ ${OCPU_VAL} -ne ${CURRENT_OCPU} ]]
   then
      echo "====> Changing VM Cluster value to ${OCPU_VAL} OCPUs"
      update_ocpu_curr_value
      CURRENT_OCPU=$(get_ocpu_curr_value)
      echo "====> Current VM Cluster OCPU Value is   : ${CURRENT_OCPU}"
   else
      echo "====> Current VM Cluster OCPU Value is equal to ${DEFAULT_OCPU}" 
      echo "      Will not execute any scale up or scale down commands"
fi

echo "************************************************************************"
echo "====>Script oci_ocpu_scale.sh ending on" `date`
echo "************************************************************************"
