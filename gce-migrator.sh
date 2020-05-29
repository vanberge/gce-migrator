#!/usr/bin/env bash
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Set up some functions, initialize vars

COUNT=0
ERROR=0
ERRORMSG="OK"

# Error out function to call if needed
ERROR_OUT() {
    if [ $ERROR -ne 0 ]; then
        echo $ERRORMSG
        echo "See help:"
        SHOW_HELP
        exit
    fi
}

# Arguments and switches input
if [[ ${#} -eq 0 ]]; then
    ERROR_OUT
else
    while getopts ":s:d:n:m:S" OPTION; do
        case $OPTION in
            s) SOURCEPROJECT_ID=${OPTARG};;
            d) DESTPROJECT_ID=${OPTARG};;
            n) NETWORK=${OPTARG};;
            m) METHOD=${OPTARG};;
            S) SHIELDED_VM=1;;
            \?) ERRORMSG="Unknown option: -$OPTARG";ERROR_OUT;;
            :) ERRORMSG="Missing option argument for -$OPTARG.";ERROR_OUT;;
            *) ERRORMSG="Unimplemented option: -$OPTARG";ERROR_OUT;;
        esac
    done
fi

# Shows help function and instructions if errors are found
SHOW_HELP() {
    echo "GCE MIGRATOR HELP"
    echo "  Use format ./gce-migrate.sh -s <sourceproject ID> -d <destproject ID> -n <network> -m <migration-type>"
    echo "      <sourceproject ID>: The project ID (not the name) where VM currently lives"
    echo "      <destproject ID>: The project ID (also, not the name) where VM will reside after migration"
    echo "      <network>: The desired network for the new VM to be connected to (Must be accessible by the destination project)"
    echo "                  alternatively, you may set to 'static' to retain the source VM IP address, but the VPC must be accessbile from the destination project"
    echo "      <migration-type>: Must be 'bulk', or a VM name - Bulk migrates all VMs in a project, and VM name will migrate that one VM"
    echo " "
    echo "  Examples:"
    echo "      ./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m myvm1"    
    echo "      ./gce-migrate.sh -s sourceproject1 -d destproject1 -n static -m myvm1 -S"
    echo "      ./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m bulk"
}

# Make sure the user entered the correct # of args.  Merge into one function to do all validation in one function
COUNT_ARGS() {
    if [ -z "$SOURCEPROJECT_ID" ] || [ -z "$NETWORK" ] || [ -z "$DESTPROJECT_ID" ] || [ -z "$METHOD" ]; then
        ERROR=1
        ERRORMSG="ERRORS FOUND IN ARGUMENTS - One or more required arguments not found"
        ERROR_OUT
    fi
}

#Check the project(s) to make sure it exists
CHECK_PROJECT() {
	gcloud projects describe $1 > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            ERROR=1
            ERRORMSG="ERRORS FOUND IN ARGUMENTS - One or more projects not found"
            ERROR_OUT
        fi
    echo "Project $1 verified"   
}

# Check destination network to make sure it exists
CHECK_NETWORK() {
    case $NETWORK in
        static) #If shared, we create the VM in the dest project, but simply have to map the subnet found in the host project shared network
            echo "Static network option, will keep $VM private IP address"
            CREATE_COMMAND() {
                    read -p "Now, delete the source VM - When done, press Enter to continue" </dev/tty
                    gcloud beta compute instances create $VM \
                    --source-machine-image projects/$SOURCEPROJECT_ID/global/machineImages/$VM-gcemigr \
                    --service-account=$DESTPROJECT_SVCACCT --zone $ZONE --project $DESTPROJECT_ID --subnet $SUBNETPATH \
                    --private-network-ip=$IP --no-address
            }
        ;;
        *)
            echo "Checking destination network $NETWORK"
            gcloud compute networks list --project $DESTPROJECT_ID | grep -w $NETWORK > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    ERROR=1 
                    ERRORMSG="ERRORS FOUND IN ARGUMENTS - Network '$NETWORK' not found for destination project"
                    ERROR_OUT
                fi
            CREATE_COMMAND() { 
                   gcloud beta compute instances create $VM \
                    --source-machine-image projects/$SOURCEPROJECT_ID/global/machineImages/$VM-gcemigr \
                    --service-account=$DESTPROJECT_SVCACCT --zone $ZONE --project $DESTPROJECT_ID --network $NETWORK --no-address
            }
        ;;
    esac
    echo "Network verified successfully"
}

# Make sure the user has picked a valid migration method - bulk, list, or single
CHECK_METHOD() {
    case $METHOD in
        bulk) #If bulk, we set our "COMMAND" to list all VMs in the project to loop through
            COMMAND() {
                gcloud compute instances list --project $SOURCEPROJECT_ID | grep -w -v NAME | awk ' { print $1 } '
            }
            ;;
        *)  # If not bulk, we assume it is  a single VM name and proceed accordingly
            WORKITEM=$METHOD #janky way to do this, maybe future update 
            VMCHECK=$(gcloud compute instances list --filter="name=( '$WORKITEM' )" | grep -w "$WORKITEM" | awk '{ print $1 }')
            if [[ -z "$VMCHECK" ]]; then
                ERROR=1
                ERRORMSG="Unable to find VM $WORKITEM" 
                ERROR_OUT
            fi 
            echo "Using single VM mode.  VM $WORKITEM will be migrated..."
            COMMAND() { # Set our command to echo the single VM name 
                echo $WORKITEM
            }
            ;;
    esac     
}

#Verify all the things before proceeding!
COUNT_ARGS
CHECK_PROJECT "$SOURCEPROJECT_ID" 
CHECK_PROJECT "$DESTPROJECT_ID" 
CHECK_NETWORK  #Maybe dont need network
CHECK_METHOD

# Now we can start!
echo "Validated command arguments... Beginning using method $METHOD"

# Get Project Names - do I even need this, idk
SOURCEPROJECT_Name=$(gcloud projects describe $SOURCEPROJECT_ID | grep 'name: ' | awk '{ print $2 }')
DESTPROJECT_Name=$(gcloud projects describe $DESTPROJECT_ID | grep 'name: ' | awk '{ print $2 }')

# Make sure that we are in the source project.  If not, go into it
echo "Checking if we are already in this project..."
CURRENTPROJECT=$(gcloud config list project | grep project | awk ' { print $3 } ')
if [ "$CURRENTPROJECT" != "$SOURCEPROJECT_ID" ]; then
    gcloud config set project $SOURCEPROJECT_ID
    if [ $? -ne 0 ]; then
        echo "Could not set project to $SOURCEPROJECT_ID, exiting"
        ERROR_OUT
        exit
    fi
    else
        echo "Already in $SOURCEPROJECT_ID, continuing!"
fi

# Make sure default CE Service account exists, add its perms to machine image use
echo "Looking for GCE service account in destination project..."
DESTPROJECT_SVCACCT=$(gcloud iam service-accounts list --project $DESTPROJECT_ID --filter="NAME=( 'Compute Engine default service account' )" | grep "Compute" | awk -F "  " '{ print $2 }') 
if [[ "$DESTPROJECT_SVCACCT" == *"gserviceaccount.com"* ]]; then
    echo "Found service account!"
    echo "Service account value is $DESTPROJECT_SVCACCT"

    else 
        echo "cannot find service account, exiting"
        exit
fi
echo "Granting access to use compute images for destination project service Account..."
gcloud projects add-iam-policy-binding $SOURCEPROJECT_ID --member serviceAccount:$DESTPROJECT_SVCACCT --role roles/compute.imageUser
    if [ $? -ne 0 ]; then
        echo "Could not set permissions for $DESTPROJECT_SVCACCT, exiting"
        exit 
    fi

# Checks are complete, now starting the migration process
echo "Reading list of VMs to migrate"
COMMAND | while read VM  # Use COMMAND function set in menu above
do
    # Get the region and zone of the instance
    echo "Currently working on $VM"
    echo "Getting Zone for $VM..."
    ZONE=$(gcloud compute instances list --filter="name=( '$VM' )" | grep -w $VM | awk '{ print $2 }')
    echo "$VM Zone is in $ZONE" 
    REGION=${ZONE::-2}
    echo "$VM region is $REGION"
   
    # Get IP information to reuse later 
    echo "Getting current IP address information for $VM"
    IP=$(gcloud compute instances describe $VM --zone $ZONE | grep "networkIP" | awk '{ print $2 }')
    SUBNET=$(gcloud compute instances describe $VM --zone $ZONE | grep -o "subnetworks/.*" | awk 'BEGIN { FS = "/" } ; { print $2 }')
    SUBNETPATH=$(gcloud compute instances describe $VM --zone $ZONE | grep subnet | grep -o "projects/.*")
    echo "IP address info is $IP, subnet is $SUBNET"

    echo "Stopping instance $VM for quiesced image..."
    gcloud compute instances stop $VM --zone $ZONE
    if [ $? -ne 0 ]; then
        echo "failed to cleanly stop VM instance $VM, exiting"
        exit
    fi

    if [ $SHIELDED_VM -ne 0 ]; then
        echo "-S detected, enabling VM Shielding options for $VM..."
        gcloud compute instances update $VM --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --zone $ZONE
    fi

    echo "Creating machine image of source VM $VM..."
    gcloud beta compute machine-images create $VM-gcemigr \
    --source-instance $VM \
    --source-instance-zone=$ZONE
    if [ $? -ne 0 ]; then
        echo "Could not save machine image of $VM, does it already exist? Exiting..."
        exit
    fi
      
    echo "Now creating VM based on new image..."
    CREATE_COMMAND
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not create new instance of $VM in $DESTPROJECT_ID"
        ERROR=1
        ERRORMSG="Could not create 1 or more VMs, please review output for errors!"
    fi
    echo "Completed migration of $VM"
done

#Done, so check error level and error out if so
ERROR_OUT
echo "Done! Please remember to delete GCE instances from source project after validation!"