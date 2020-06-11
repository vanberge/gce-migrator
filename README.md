# Google Cloud Compute Instance Migrator 

GCE migrator is a script developed to help "migrate" Google cloud compute instances to a new project.  
Since this functionality does not yet exist natively in GCP, the script will stop GCE instances, 
take a machine image of those instances, and deploy new GCE VMs from those machine image in the destination project of your choosing.

## Disclaimer

This migration tool is provided without any warranty, make sure you review the script code and test accordingly with your requirements.
Always make sure you have backups and have **validated** recovery from those backups before running, especially in production environments.
This cannot be stressed enough.

## Getting Started

* Make sure you know the source project id, destination project id, and which network you would like to attach to.  
* If you intend to keep the source VM IP address, the VPC network must be shared between source and destination projects.
* Keeping the same IP address will require the **source VM to be removed** after taking a machine image.  The script will not do this for you, but will prompt you when to do it.
* If not using the same IP (IE, attaching to a new VPC network at the destination), recognize that there will be 2 VM instances and that a cleanup should be performed on the source once destination is completed.


## Usage 

* Make sure you install the Google cloud SDK (or, just use CloudShell).
   * If running outside of cloud shell, authenticate by running "gcloud auth login" 
* Clone the repository: "git clone https://github.com/vanberge/gce-migrator.git"
* Change directory into the gce-migrator folder and run the script per the usage options below
* Use format:  ./gce-migrate.sh -s <sourceproject ID> -d <destproject ID> -n <network> -m <migration-type> -S <optional>

### Required options
* **-s <sourceproject id>**: The project ID where VM currently lives
* **-d <destproject id>**: The project ID where VM will reside after migration
* **-n <network>**: The destination network that the new instance of the VM will be connected to. Values are the name of the destination network, or "static" to keep the existing IP.
    * network name - If passing network name, the VM will be connected to the network specified with the next available IP address.
    * static - If passing 'static', the script will retain the IP address of the VM instance.
    * **NOTE**:  Setting the network 'static' will require the deletion of the source VM before creating the new instance in the destination project.  The script will prompt you to do this, but you MUST Have a backup and recovery scenario in the even this does not work.
* **-m <migration>**: Must pass a single VM name, or "bulk".
    * bulk - use the "bulk" argument to migrate all GCE instances in the source project into the destination project and network.
    * Single VM - Pass "-m vmname" arguments to migrate a single GCE instance
    
### Optional parameters
* **-S:**  enable Secure/Shielded VM as part of the conversion.  Only needed if source is NOT shielded, and you wish the destination to be shielded.

## Examples:
```
./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m myvm1
   - This will migrate the VM "myvm1" from sourceproject1 to destproject1 using the default VPC network

./gce-migrate.sh -s sourceproject1 -d destproject1 -n static -m myvm1
   - This will migrate the VM "myvm1" from sourceproject1 to destproject1, keeping myvm1's private IP address
   - As noted above, this requires the VM's VPC network/subnet to be shared with the destination project

./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m bulk 
   - Migrates all VMs in sourceproject1 to destproject
   - Attaches the VMs to the default network

./gce-migrate.sh -s sourceproject1 -d destproject1 -n default -m bulk -S
   - This will migrate all VM instances in sourceproject1 to destproject1, connecting to the default VPC network.
   - Enables shielded VM options on the VM as part of the migration
```

## Cleanup
If moving to a new network, this migration script will leave a stopped GCE instance in the source project, as well as machine images for all migrated VMs.
Once functionality is validated at the destination, these items should be cleaned up per best practices and to avoid any future interruption.


### Authors
* **Eric VanBergen** - [Github](https://github.com/vanberge) - [Personal](https://www.ericvb.com)


### License
This project is licensed under the Apache 2 License - see the [LICENSE.md](LICENSE.md) file for details
