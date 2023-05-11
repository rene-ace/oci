#!/bin/bash
#set -x
############################################################################################
## oci_ocpu_scale.sh
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
##        HIGHEST_OCPU_VAL:96
##        LOWEST_OCPU_VAL:12
##
## SCRIPT PROCESS FLOW:
##
## OUTPUTS: Standard Output via command line execution.
##
## NOTIFICATION: Standard Output via command line execution.
##
## MODIFICATIONS:
##
##   Date          Name                      Description
##   (DD/MM/YYYY)
##   ----------    --------------            --------------------------------------
##   11/04/2021    Rene Antunez              Created
##   01/06/2021    Rene Antunez              Added JSON logfile support
##   15/09/2021    Rene Antunez              Added Warm Up/Cool Down capability
##   22/03/2022    Rene Antunez              Validation of OCPU values
##   09/07/2022    Dinusha Rathnamalala      Added the function obtain_scale_ocpu_val for more precise OCPU scaling
##   03/11/2022    Dinusha Rathnamalala      Added current VM status verification capability
##   
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
                         [ -i | --ocid ]
                         [ -c | --cooldown ]
                         [ -w | --warmup ]"
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
   HIGHEST_OCPU_VAL)        HIGHEST_OCPU_VAL=`echo $input_file |cut -d: -f2` ;;
   COOL_DOWN_OCPU_VAL)      COOL_DOWN_OCPU_VAL=`echo $input_file |cut -d: -f2` ;;
   WARM_UP_OCPU_VAL)        WARM_UP_OCPU_VAL=`echo $input_file |cut -d: -f2` ;;
   LOWEST_OCPU_VAL)         LOWEST_OCPU_VAL=`echo $input_file |cut -d: -f2` ;;
esac
done < ${INPUT_FILE}

export VM_CLUSTER_OCID DEFAULT_OCPU HIGHEST_OCPU_VAL COOL_DOWN_OCPU_VAL WARM_UP_OCPU_VAL
}

################################################################################
# validate_ocpu_values ()
# This function validates the minimum and maximum OCPU values that
# the customer can scale up or down
################################################################################
validate_ocpu_values ()
{
value=${1}
if [ $((value%2)) -eq 0 ]
then
   if [ ${1} -lt ${LOWEST_OCPU_VAL} ];
   then
      echo "====> VM Cluster OCPU count of ${1} is : INVALID"
      echo "      OCPU value needs to higher than the config value of LOWEST_OCPU_VAL:${LOWEST_OCPU_VAL}"
      print_header_footer "ending"
      exit 1
   fi
   if [ $1 -eq 0 ];
   then
         if [ "${COOL_DOWN}" = "true" ]
         then
           echo "====> New VM Cluster OCPU count of ${1} is : INVALID"
           echo "      Cool Down Value would shutdown the VM"
           print_header_footer "ending"
           exit 1
         else
           echo "====> New VM Cluster OCPU count of ${1} is : VALID"
           echo "      With an OCPU value of 0 VM will be shutdown"
         fi
   elif [ $1 -gt 3 -a $1 -le ${2} ];
   then
      echo "====> New VM Cluster OCPU count of ${1} is : VALID"
   else
      echo "====> New VM Cluster OCPU count of ${1} is : INVALID"
      echo "      Valid OCPU Range is 0 or 4 - ${2} "
      print_header_footer "ending"
      exit 1
   fi
else
   echo "====> VM Cluster OCPU count of ${1} is : INVALID"
   echo "      OCPU value needs to be 0 or an even number"
   print_header_footer "ending"
   exit 1
fi

if [ ${1} -lt ${LOWEST_OCPU_VAL} ];
then
   echo "====> VM Cluster OCPU count of ${1} is : INVALID"
   echo "      OCPU value needs to higher than the config value of LOWEST_OCPU_VAL:${LOWEST_OCPU_VAL}"
   print_header_footer "ending"
   exit 1
fi

}

################################################################################
# validate_vm_status ()
# This function validates if the status of the VM is available to scale up/down
################################################################################
validate_vm_status ()
{
if [ "${1}" != "AVAILABLE" ]; then
   echo "====> VM Cluster is not currently available. Status is : ${1}. Retrying within $WAIT_TIME minutes."
   clus_status=$(get_curr_clus_status)
   x=1
   while [ $x -le $WAIT_TIME ] && [ $clus_status != "AVAILABLE" ]
   do
     sleep 60
     rtime=$(( $WAIT_TIME - $x ))
     echo "====> VM Cluster status is $clus_status. Retrying after 1 minute. The time remaining: $rtime minutes."
     x=$(( $x + 1 ))
     clus_status=$(get_curr_clus_status)
   done
   if [ $clus_status != "AVAILABLE" ]; then
       echo "====> OCPU script execution failure: The VM cluster status is "$clus_status" after $WAIT_TIME minutes. Sending an email to $DEST_EMAIL"
       echo "OCPU script execution failure: The VM cluster status is "$clus_status". Wait until the status change to AVAILABLE and re-execute the process manually." | mail -s "$SUBJECT" "$DEST_EMAIL"
       print_header_footer "ending"
       exit 1
   fi
   echo "====> VM Cluster status changed to $clus_status. Script continue."
   sleep 30
fi
}

###############################################################################
# get_curr_clus_status ()
# This function will read from OCI the current cluster status
###############################################################################

get_curr_clus_status()
{
oci db vm-cluster get --vm-cluster-id ${VM_CLUSTER_OCID} | jq -r .data.\"lifecycle-state\"
}

################################################################################
# get_ocpu_curr_value ()
# This function will read from OCI the current OCPU value
################################################################################
get_ocpu_curr_value()
{
oci db vm-cluster get --vm-cluster-id ${VM_CLUSTER_OCID} | jq -r .data.\"display-name\",.data.\"cpus-enabled\",.data.\"lifecycle-state\"
}

################################################################################
# get_vm_value ()
# This function will read from OCI the VM count of the cluster
################################################################################
get_vm_value()
{
oci db vm-cluster get --vm-cluster-id ${VM_CLUSTER_OCID} | jq -r .data.\"db-servers\" | jq '. | length'
}

################################################################################
# update_ocpu_curr_value ()
# This function will update from OCI the current OCPU value
################################################################################
update_ocpu_curr_value()
{
#oci db vm-cluster update --cpu-core-count ${OCPU_VAL} --vm-cluster-id ${VM_CLUSTER_OCID} --wait-for-state AVAILABLE | jq -r .data.\"display-name\" > /dev/null
oci db vm-cluster update --cpu-core-count ${OCPU_VAL} --vm-cluster-id ${VM_CLUSTER_OCID} --wait-for-state AVAILABLE --wait-interval-seconds 10 | jq -r .data.\"display-name\" > /dev/null

}

################################################################################
# write_log_file ()
# This function will write the log file for the scale up/scale down actions
################################################################################
write_log_file()
{
ocpu_date_change=`date +"%d-%b-%Y"`
ocpu_time_change=`date +"%H:%M:%S"`

if [ ! -f ${LOG_HOME}/${1}.json ]; then
   cat > ${LOG_HOME}/${1}.json <<EOF
{
  "messages": [
    {
      "vm": "${1}",
      "cpus": ${2},
      "date": "${ocpu_date_change}",
      "time": "${ocpu_time_change}"
    }
  ]
}
EOF

else
   a_first_date=`cat ${LOG_HOME}/${1}.json | jq '.messages[0].date' | tr -d \"`
   first_date=`date -d "${a_first_date}+30days" +"%Y%m%d%H%M%S"`

   today_date=`date +"%Y%m%d%H%M%S"`
   if [ ${first_date} -le ${today_date} ];
   then
      tar -czvf ${LOG_HOME}/${1}.${today_date}.tar.gz ${LOG_HOME}/${1}.json --remove-files > /dev/null 2>&1
      cat > ${LOG_HOME}/${1}.json <<EOF
{
  "messages": [
    {
      "vm": "${1}",
      "cpus": ${2},
      "date": "${ocpu_date_change}",
      "time": "${ocpu_time_change}"
    }
  ]
}
EOF
   else
      jq --arg VM_NAME "${1}" --arg CURRENT_OCPU "${2}" --arg ocpu_date_change "${ocpu_date_change}" --arg ocpu_time_change "${ocpu_time_change}" \
      '.messages += [{"vm":$VM_NAME,"cpus":$CURRENT_OCPU,"date":$ocpu_date_change,"time":$ocpu_time_change}]' ${LOG_HOME}/${1}.json \
      > ${LOG_HOME}/${1}.json.tmp && mv -f ${LOG_HOME}/${1}.json.tmp ${LOG_HOME}/${1}.json
   fi
fi
}

################################################################################
# obtain_scale_ocpu_val ()
# This function will define the correct value that the OCPU needs to be scaled
# up or down
################################################################################
obtain_scale_ocpu_val ()
{
   if [ -n "${SCALE_OCPU_VAL}" ]
   then
      OCPU_VAL=${SCALE_OCPU_VAL}
   else
      if [ "${COOL_DOWN}" = "true" ] || [ "${WARM_UP}" = "true" ]
      then
         if [ "${COOL_DOWN}" = "true" ]
         then
            COOL_DOWN_OCPU_VAL=$((COOL_DOWN_OCPU_VAL*VM_COUNT))
            OCPU_VAL=$((CURRENT_OCPU-COOL_DOWN_OCPU_VAL))
         elif [ "${WARM_UP}" = "true" ]
         then
            WARM_UP_OCPU_VAL=$((WARM_UP_OCPU_VAL*VM_COUNT))
            OCPU_VAL=$((CURRENT_OCPU+WARM_UP_OCPU_VAL))
         else
            OCPU_VAL=${DEFAULT_OCPU}
         fi
      else
         OCPU_VAL=${DEFAULT_OCPU}
      fi
   fi
   export OCPU_VAL
}

################################################################################
# print_header_footer ()
# This function will print the header and footer of the script
################################################################################
print_header_footer ()
{
   echo "************************************************************************"
   echo "====> Script oci_ocpu_scale.sh is ${1} on" `date`
   echo "************************************************************************"
}



################################################################################
##  ------------------------------------------------------------------------  ##
##                        MAIN SCRIPT EXECUTION                               ##
##  ------------------------------------------------------------------------  ##
################################################################################
source ~/.bash_profile
print_header_footer "starting"

################################################################################
# Beginning of parsing arguments
################################################################################
COOL_DOWN="false"
WARM_UP="false"
export COOL_DOWN WARM_UP
# make args an array, not a string
args=( )

# replace long arguments
for arg; do
    case "$arg" in
        --status)         args+=( -s ) ;;
        --scale_ocpu)     args+=( -o ) ;;
        --ocid)           args+=( -i ) ;;
        --cooldown)       args+=( -c ) ;;
        --warmup)         args+=( -w ) ;;
        *)                args+=( "$arg" ) ;;
    esac
done

#printf 'args before update : '; printf '%q ' "$@"; echo
set -- "${args[@]}"
#printf 'args after update  : '; printf '%q ' "$@"; echo

while getopts "so:i:cw" OPTION; do
    : "$OPTION" "$OPTARG"
    # echo "optarg : $OPTARG"
    case $OPTION in
    s)  STATUS="true" ;;
    o)  SCALE_OCPU_VAL=("$OPTARG");;
    i)  VM_CLUSTER_OCID="$OPTARG";;
    c)  COOL_DOWN="true" ;;
    w)  WARM_UP="true" ;;
    esac
done

################################################################################
#  End of parsing arguments
#  This function will parse the arguments passed to the script
################################################################################

################################################################################
# Set Variables Section
################################################################################
export SCRIPT_HOME=$HOME/scripts
export CONFIG_HOME=$SCRIPT_HOME/config
export LOG_HOME=$SCRIPT_HOME/logs
read_input_pars
DO_NOT_CHANGE_OCPU_LOCK="${CONFIG_HOME}/do_not_change_ocpu"

if [ -z "$VM_CLUSTER_OCID" ]; then
   usage
fi

if [ "${COOL_DOWN}" = "true" ] && [ "${WARM_UP}" = "true" ]; then
   usage
fi

export VM_CLUSTER_OCID

GET_OCPU=$(get_ocpu_curr_value)
GET_VM=$(get_vm_value)
CURRENT_OCPU=`echo ${GET_OCPU} | awk -v OFS='\t' '{print $2}'`
VM_NAME=`echo ${GET_OCPU} | awk -v OFS='\t' '{print $1}'`
VM_STATUS=`echo ${GET_OCPU} | awk -v OFS='\t' '{print $3}'`
VM_COUNT=`echo ${GET_VM} | awk -v OFS='\t' '{print $1}'`
DO_NOT_CHANGE_OCPU_LOCK="${CONFIG_HOME}/ocpu_prevent_scale_${VM_NAME}.lck"
SUBJECT="$(date +%y)/$(date +%m)/$(date +%d) $(date +%H).$(date +%M).$(date +%S) - OCPU autoscaling burst failure on PROD {$VM_NAME}"
DEST_EMAIL=databaseservices@canadalife.com
WAIT_TIME=15
export CURRENT_OCPU VM_STATUS VM_NAME VM_COUNT WAIT_TIME SUBJECT DEST_EMAIL

################################################################################
# Execution of Script
################################################################################
echo "====> Current VM Cluster OCPU Value is   : ${CURRENT_OCPU}"

validate_vm_status ${VM_STATUS}
obtain_scale_ocpu_val

if [ "${STATUS}" = "true" ]; then
   print_header_footer "ending"
   exit 0
fi

validate_ocpu_values ${OCPU_VAL} ${HIGHEST_OCPU_VAL}

if [[ -f "${DO_NOT_CHANGE_OCPU_LOCK}" ]]
   then
      echo "====> Currently file ${DO_NOT_CHANGE_OCPU_LOCK} "
      echo "      is not allowing OCPU Modifications"
      echo "      Remove lock before re-execution"
      echo "      Exiting..."
      print_header_footer "ending"
      echo "OCPU script execution failure. Lock file $DO_NOT_CHANGE_OCPU_LOCK exists. Remove the lock file and re-execute the process manually." | mail -s "$SUBJECT" "$DEST_EMAIL"
      exit 1
   fi
   CUR_CLUS_STATUS=$(get_curr_clus_status)
   if [[ ${CUR_CLUS_STATUS} = "AVAILABLE" ]]
      then
         if [[ ${OCPU_VAL} -ne ${CURRENT_OCPU} ]]
            then
                echo "====> Changing VM Cluster value to ${OCPU_VAL} OCPUs"
                update_ocpu_curr_value
                GET_OCPU=$(get_ocpu_curr_value)
                CURRENT_OCPU=`echo ${GET_OCPU} | awk -v OFS='\t' '{print $2}'`
                VM_NAME=`echo ${GET_OCPU} | awk -v OFS='\t' '{print $1}'`
                write_log_file ${VM_NAME} ${CURRENT_OCPU}
                echo "====> Current VM Cluster OCPU Value is   : ${CURRENT_OCPU}"
            else
                echo "====> Current VM Cluster OCPU Value is equal to ${DEFAULT_OCPU}"
                echo "      Will not execute any scale up or scale down commands"
      #echo "OCPU script execution failure: The current VM cluster OCPU Value (${DEFAULT_OCPU}) is equal to default OCPU. Will not execute any scale up or scale down commands." | mail -s "$SUBJECT" "$DEST_EMAIL"
         fi
       else
           echo "====> OCPU script execution failure: The VM cluster status  "$CUR_CLUS_STATUS" does not allow scale up/down operations. Sending an email to $DEST_EMAIL"
          echo "OCPU script execution failure: The VM cluster status "$CUR_CLUS_STATUS" does not allow scale up/down operations. Wait until the status become AVAILABLE and re-execute the process manually." | mail -s "$SUBJECT" "$DEST_EMAIL"
       print_header_footer "ending"
       exit 1

fi
print_header_footer "ending"

################################################################################
# End of Execution of Script
################################################################################
