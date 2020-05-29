# GCE Migrator 

GCE migrator is a script developed to help "migrate" compute instances to a new GCE project.  
Since this functionality does not yet exist natively in GCP, the script will stop GCE instances, 
take a machine image of those instances, and deploy new GCE VMs from those machine image in the destination project of your choosing.

## Disclaimer

This migration tool is provided without any warranty, make sure you review the script code and test accordingly with your requirements.
Always make sure you have backups and have **validated** recovery from those backups before running, especially in production environments.

## Getting Started

* Make sure you know the source project id, destination project id , and which network you would like to attach to.  
* If you intend to keep the source VM IP address, the VPC network must be shared between the two projects.
* Keeping the same IP address will require the **source VM to be removed** after taking a machine image.  The script will walk you through this.
* If not using the same IP (IE, attaching to a new VPC network at the destination), recognize that there will be 2 VM instances and that a cleanup should be performed on the source once destination is completed.


## Usage 

Clone the repository, and make sure you install the Google cloud SDK (or, just run the script from CloudShell).
If running outside of cloud shell, authenticate by running "gcloud auth login" 

Use format ./gce-migrate.sh -s <sourceproject ID> -d <destproject ID> -n <network> -m <migration-type> -S <optional>

### Required options
* **-s <sourceproject id>**: The project ID where VM currently lives
* **-d <destproject id>**: The project ID where VM will reside after migration
* **-n <network>**: The desired network for the new VM to be connected to (Must be accessible by the destination project).  
    * Alternatively, use "static" as the option to keep the source VMs IP info (which requires a shared VPC)
    * **NOTE**:  Setting the network "static" means that you have to delete the source VM before creating the new instance in the destination.
    * The script will prompt you to do this, but you MUST Have a backup and recovery scenario in the even this does not work.
* **-m <migration>**: Must pass "bulk", "list", or a single VM name.
    * bulk - use the "bulk" argument to migrate all GCE instances in the source project into the destination project and network.
    * list - use "list" and the script will prompt for a text file </path/to/vms.txt> listing of GCE instance names to migrate.
    * Single VM - Pass "-m vmname" arguments to migrate a single GCE instance
### Optional parameters
* -S:  enable Secure/Shielded VM as part of the conversion.  Only needed if source is NOT shielded, and you wish the destination to be shielded

## Examples:
```
./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m myvm1
   - This will migrate the VM "myvm1" from sourceproject1 to destproject1 using the default VPC network

./gce-migrate.sh -s sourceproject1 -d destproject1 -n static -m myvm1
   - This will migrate the VM "myvm1" from sourceproject1 to destproject1, keeping myvm1's private IP address
   - As noted above, this requires the VM's VPC network/subnet to be shared with the destination project

./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m list 
   - This will prompt for a text file list </path/to/myvmlist.txt> 
   - Once entered, all VMs listed in /path/to/myvmlist.txt from sourceproject1 to destproject1 and connect them to the default VPC network.

./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m bulk
   - This will migrate all VM instances in sourceproject1 to destproject1, connecting to the default VPC network.
```

## Cleanup
If moving to a new network, this migration script will leave a stopped GCE instance in the source project, as well as machine images for all migrated VMs.
Once functionality is validated at the destination, these items should be cleaned up per best practices and to avoid any future interruption.


### Authors
* **Eric VanBergen** - *Initial work* - [Github](https://github.com/vanberge)


### License
This project is licensed under the Apache 2 License - see the [LICENSE.md](LICENSE.md) file for details
