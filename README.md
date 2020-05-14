# GCE Migrator 

GCE migrator is a script developed to help "migrate" compute instances to a new GCE project.  Since this functionality does not yet exist natively in GCP, the script will stop GCE instances, take a machine image of those instances, and deploy new GCE VMs from those machine image in the destination project of your choosing.

## Getting Started

Make sure you know the source project, destination project, and which network you would like to attach to.  In the case of using a shared VPC, just recognize that there will be 2 VM instances and that a cleanup should be performed on the source once destination is completed.


## Usage 
Clone the repository, and make sure you install the Google cloud SDK (or, run the script from CloudShell).
If running outside of cloud shell, authenticate by running "gcloud auth login" 

Use format ./gce-migrate.sh <sourceproject> <destproject> <network> <migration-type>
    sourceproject: The project where VM currently lives
    destproject: The project where VM will reside after migration
    network: The desired network for the new VM to be connected to (Must be accessible by the destination project)
    migration-type: Must be 'bulk', 'list', or a 'single' - Bulk migrates all VMs in a project, list will prompt for a text file listing, and single will request a VM name

### Migration Type
This script enables migration using 3 strategies:
* Single VM - Pass the "single" and "vmname" arguments to migrate a single GCE instance
* List - pass the "list" and /path/to/list.txt for a text listing of GCE instance names to migrate
* Bulk - use the "bulk" argument to migrate all GCE instances in the source project into the destination project and network.

### Examples:
```
./gce-migrate.sh sourceproject1 destproject1 default single myvm1
   - This will migrate the VM "myvm1" from sourceproject1 to destproject1 using the default VPC network

./gce-migrate.sh sourceproject1 destproject1 default list /path/to/myvmlist.txt
   - This will migrate all VMs listed in /path/to/myvmlist.txt from sourceproject1 to destproject1 and connec them to the default VPC network.


./gce-migrate.sh sourceproject1 destproject1 default bulk
   - This will migrate all VM instances in sourceproject1 to destproject1, connecting to the default VPC network.
```
### Cleanup
This migration script will leave a stopped GCE instance in the source project, as well as machine images for all migrated VMs.
Once functionality is validated at the destination, these items should be cleaned up per best practices and to avoid any future interruption.


### Authors

* **Eric VanBergen** - *Initial work* - [Github](https://github.com/vanberge)


### License

This project is licensed under the Apache 2 License - see the [LICENSE.md](LICENSE.md) file for details

