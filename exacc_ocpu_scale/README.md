**Script Setup and Usage**

**1.- Create the RSA private/public keys and find the fingerprint of the RSA key**

```
[oracle@localhost ~]$ mkdir ~/.oci 
[oracle@localhost ~]$ cd ~/.oci 
[oracle@localhost ~]$ openssl genrsa -out ~/.oci/oci_api_key.pem 2048 
Generating RSA private key, 2048 bit long modulus
...................................................................+++
....................+++
e is 65537 (0x10001)
[oracle@localhost ~]$ chmod go-rwx ~/.oci/oci_api_key.pem  
[oracle@localhost ~]$ openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem 
writing RSA key         
[oracle@localhost ~]$ openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
writing RSA key
78:**:**:**:**:**:**:**:**:**:**:**:**:**:**:8g
[oracle@localhost ~]$ cat ~/.oci/oci_api_key_public.pem | pbcopy  
```

**2. Log in to Oracle Cloud Infrastructure  and go to my user settings as the picture below.**

  In my user settings,add the public key in the Resources section called API Keys 

  In the next screen, choose Paste Public Key,paste the public key I copied above and click on Add.

**3. After the key has been added, it will generate a Configuration File called config that we will use in my local ~/.oci directory. Just substitute the key_file part of it to use my private RSA key that it was previously generated.**
```
   [oracle@localhost ~]$ pwd
   /Users/*****/.oci
   [oracle@localhost ~]$ cat config
   [DEFAULT]
   user=ocid1.user.*************************************
   fingerprint=12*************************************:2c
   tenancy=ocid1.tenancy.oc1.*************************************
   region=ca-toronto-1
   key_file=/Users/****/.oci/oci_api_key.pem
``` 

**4. The next thing is to install oci-cli (Oracle Linux 8 )**
```
   [oracle@localhost ~]$ sudo dnf -y install oraclelinux-developer-release-el8
   [oracle@localhost ~]$ sudo dnf install python36-oci-cli
   #The CLI will be installed to the Python site packages:

   /usr/lib/python3.6/site-packages/oci_cli
   /usr/lib/python3.6/site-packages/services
```
**5. For Oracle Linux 7**
```
   [oracle@localhost ~]$  sudo yum install python36-oci-cli -y
   # The CLI will be installed to the Python site packages:

   /usr/lib/python3.6/site-packages/oci_cli
   /usr/lib/python3.6/site-packages/services
```   
   Install jq which is json parser.
```
   [oracle@localhost ~]$ sudo yum install jq -y
```
**6. Test out if the connectivity is working towards your OCI Tenancy**
```
[oracle@localhost ~]$ oci iam region list --output table
+-----+----------------+
| key | name           |
+-----+----------------+
| AMS | eu-amsterdam-1 |
| BOM | ap-mumbai-1    |
| CWL | uk-cardiff-1   |
| DXB | me-dubai-1     |
| FRA | eu-frankfurt-1 |
| GRU | sa-saopaulo-1  |
| HYD | ap-hyderabad-1 |
| IAD | us-ashburn-1   |
| ICN | ap-seoul-1     |
| JED | me-jeddah-1    |
| KIX | ap-osaka-1     |
| LHR | uk-london-1    |
| MEL | ap-melbourne-1 |
| NRT | ap-tokyo-1     |
| PHX | us-phoenix-1   |
| SCL | sa-santiago-1  |
| SJC | us-sanjose-1   |
| SYD | ap-sydney-1    |
| YNY | ap-chuncheon-1 |
| YUL | ca-montreal-1  |
| YYZ | ca-toronto-1   |
| ZRH | eu-zurich-1    |
+-----+----------------+
```
**7. Create the following directories**
```
   [oracle@localhost ~]$ mkdir $HOME/scripts
   [oracle@localhost ~]$ mkdir $HOME/scripts/config
   [oracle@localhost ~]$ mkdir $HOME/scripts/logs
```
**8. Proceed to create the script called oci_ocpu_scale.sh in $HOME/scripts**

 
**9. This script uses a control file called oci_inputs.ctl in $HOME/scripts/config which will have the following 3 parameters. 
   It is important to know that the value of DEFAULT_OCPU can be overridden if a value is passed as a first parameter to the script.**
```
   VM_CLUSTER_OCID:CHANGE_OCID_FOR_ACTUAL_VALUE # EXACC VM CLUSTER OCID
   DEFAULT_OCPU:32 # VALUE OF OCPUs CONSIDERED AS DEFAULT
   HIGHEST_OCPU_VAL:100 # MAXIMUM VALUE OF OCPUS THAT CAN BE SCALED UP TO
   COOL_DOWN_OCPU_VAL:2 #COOL DOWN OCPU VALUES
   WARM_UP_OCPU_VAL:4 #WARM UP OCPU VALUES
```
**10. The script will check for a lock file, called do_not_change_ocpu, in case you don’t want the script to override the current OCPU values of your ExaCC VM Cluster and also will not execute the update command if the new OCPU value is equal to the current OCPU value.**
```
Usage is 


Usage: oci_ocpu_scale.sh   [ -s | --status ] 
                           [ -o | --scale_ocpu ]
                           [ -i | --ocid ]
                           [ -c | --cooldown ]
                           [ -w | --warmup ]
e.g.
    oci_ocpu_scale.sh -i ocid1.vmcluster.oc1.ca-toronto-1.aaaaaaaabbbbbbddddddd -o 16

Note 1:    [ -i | --ocid ] is a mandatory value

Note 2: If [ -o | --scale_ocpu ] is empty,
        It will use the values of config/oci_inputs.ctl

Note 3: File config/do_not_change_ocpu will not allow a change of OCPUs
When you run the script, it will look something like this.

Note 4: If [ -c] or [-w] it will use the current OCPU value and either substract or add the value of the COOL_DOWN_OCPU_VAL or WARM_UP_OCPU_VAL from oci_inputs.ctl
```
**Example of execution**
```
[oracle@localhost ~]$ oci_ocpu_scale.sh -i <OCID_VM_VALUE> -o 10 
************************************************************************
====>Script oci_ocpu_scale.sh starting on Fri 31 Dec 2021 10:16:58 EST
************************************************************************
====> Current VM Cluster OCPU Value is   : 32
====> New VM Cluster OCPU count of 10 is : VALID
====> Changing VM Cluster value to 10 OCPUs
Action completed. Waiting until the resource has entered state: ('AVAILABLE',)
vorade
====> Current VM Cluster OCPU Value is   : 10
************************************************************************
====>Script oci_ocpu_scale.sh ending on Fri 31 Dec 2021 10:22:28 EST
************************************************************************
```
