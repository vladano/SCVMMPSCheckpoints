These are powershell scripts to create/restore and delete checkpoints on Hyper-V VMs that are administered using SCVMM 2019/2016 powershell commands.
The problem of creating checkpoints on VMs using .vhdx share disks, which are used when creating MS SQL clusters with 2 nodes, is specially treated.
By using a shared HHD between 2 x VMs, the MS SQL cluster configuration is simulated when the database is placed on a network location that is physically located on the storage.

A prerequisite for these scripts to work is that the name for each VM is in the following format:
VM_NAME - System_Name
If the names of the VMs are not defined in the specified format, it is necessary to correct the part within the script that filters the list of virtual machines in such a way that it can include another
the logic your virtual machines are subject to.

Creating checkpoints on all VMs from the system
--------------------------------------------------
Since in my case all virtual machines are members of one or more Windows Active Directory systems, at the beginning of the script, shutdown of all virtual machines from the system is done because
only in that case can it be 100% guaranteed that after the machine restore, the integrity of each VM within the Active Directory domain will be safely preserved.

Then it goes through the entire list of VMs and dismounts any DVD files mounted on the VM.

In order to enable the creation of a checkpoint on VMs with a shared .vhdx file, the following algorithm was applied:
- goes through all VMs and detects if there are VMs with shared .vhdx files on the system
-determine the amount of free space required for backup shared .vhdx files
- remove shared .vhdx files from VMs if they exist
- copy the shared .vhdx files to the backup location
-create a checkpoint on all VMs from the specified system
- automatic addition of shared .vhdx disks is performed on VMs where previously shared .vhdx disks were created
-refresh all VMs from the system

Restore checkpoints on all VMs from the system
----------------------------------------------
- it goes through the entire list of VMs from the system and creates a list of VMs with shred .vhdx files.
-restore previously created checkpoint on virtual machines.
- then the previously copied shared .vhdx files are copied from the specified backup location to the original location of each VM.
- automatic addition of shared .vhdx disks is performed on VMs where previously shared .vhdx disks were created
-refresh all VMs from the system