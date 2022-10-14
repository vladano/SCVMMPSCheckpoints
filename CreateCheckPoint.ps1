Function CreateCheckPoint
{
    <#
        .SYNOPSIS
            Create Check point for VM(s) contain system name.

        .DESCRIPTION
            Create Check point for VM(s) contain system name.

            To Test from PowerShell IDE use following command:
            Import-Module -Name ".\CreateCheckPoint.ps1" -Force

            CreateCheckPoint -SystemName "-Deployment_Training" -CheckPointName "workgroup"

            or

            CreateCheckPoint -SystemName "-TrainingSystem01" -CheckPointName "20191205" -BackupLocation "\\server01\Backup\TrainingSystem01"

        .PARAMETER $SystemName
            Name of System.
			Each VM contain inside VM name that string.
            Note:
            !!!!!!!!!!
            System Name MUST be last part of VM name
            !!!!!!!!!!!

        .PARAMETER $CheckPointName
            Check point name for selected VM inside entered System Name.
            Note: 
            !!!!!!!!!!
            Each VM inside System name, must have the same check point name 
            !!!!!!!!!!

        .PARAMETER $BackupLocation
            Full path of folder to store shared VHD file if exists

        .ExAMPLE
            Create check point name 'workgroup' for VMs inside system name "-Deployment_Training"
            NOTE:
            System without shared HDD(s)

			CreateCheckPoint  -SystemName "-Training01" -CheckPointName "workgroup"

        .ExAMPLE
            Create check point name '20191103' for VMs inside system name "-Training01" and if exist shared HDD(s) copy to location "\\server01\Backup\TrainingSystem01" 

			CreateCheckPoint -SystemName "-Training01" -CheckPointName "20191217" -BackupLocation "\\server01\Backup\TrainingSystem01" 

        .NOTES
            Author: Vladan Obradovic
            Last Edit: 09.09.2020 DD/MM/YYYY
            Version 1.0 - Initial release of restore checkpoint
            Version 1.1 - Version that support ONLY ONE checkpoint per [SystemName]
                          Using powershell command from SCVMM except for add shared hdd to VM(s)
                          During execution all actions can be monitored using SCVMM Jobs console.
            Version 2.0 - Version that support multiple checkpoints per [SystemName]
            Version 2.1 - Added support for NON standard shared disks configuration with support multiple checkpoints per [SystemName]
            Version 2.2 - Added more detailed printing of messages in case of warnings and errors that may occur during script execution
            Version 2.3 - Added check in case the script for any reason did not detect the existence of shared HDDs on the 
                          system and there is a value for the parameter [Backup location]. Scipt can be terminated/continue
                          using dialog value Yes/No
            Version 2.4 - Added additional check on beggining of script if ISO file mounted on VM(s) 
            Version 2.5 - Added better check if ISO file mounted on VM(s) 
            Version 2.6 - 2020-10-06
                          Added output log messages to file inside .\Log folder 
                          List shared HDD information inside console and write that data to log messages file inside .\Log folder 
            Version 2.7 - 2020-11-03
                          Add file size to display when copy file from original location to backup location  
            Version 2.8 - 2021-04-09
                          Add breakpoint comment  
    #>
    [CmdletBinding()]  
    param
    (
        [parameter(Position=0,Mandatory=$true,HelpMessage="You must enter System Name")]
        [string]$SystemName="",

        [parameter(Position=1,Mandatory=$true,HelpMessage="You must enter check point name")]
        [string]$CheckPointName="",

        [parameter(Position=2,Mandatory=$false,HelpMessage="You must enter full path for folder location")]
        [string]$BackupLocation=""

    )
    BEGIN
    {
        $StartDate=Get-Date
        $date = Get-Date -Format yyyy-MM-dd
        $time = get-date -Format HH:mm:ss
        $timeFile = get-date -Format HH-mm-ss
        $datetime = $date + "|" + $time

        $currentDir= Get-Location
        $outLogFileName= $currentDir.Path + '\Log'

        if (-not (Test-Path $outLogFileName -PathType Container))
        {
            $outLogFileName
            New-Item -Path $outLogFileName -ItemType "directory" 
            $outLogFileName
        }

        $outLogFileName= $outLogFileName + "\" + $SystemName + "_" + $date + "_" + $timeFile + ".txt"

        if (Test-Path $outLogFileName -PathType Leaf )
        {
            Remove-Item $outLogFileName
        }

        Write-Output "`nStart time [$datetime]`nStarting CreateCheckPoint ..."
        Write-Output "`nStart time [$datetime]`nStarting CreateCheckPoint ..." | Out-File -FilePath $outLogFileName -Append

		Function Start-Countdown 
		{   
            <#
			.SYNOPSIS
				Provide a graphical countdown if you need to pause a script for a period of time
			.PARAMETER Seconds
				Time, in seconds, that the function will pause
			.PARAMETER Messge
				Message you want displayed while waiting
			.EXAMPLE
				Start-Countdown -Seconds 30 -Message Please wait while Active Directory replicates data...
			.NOTES
				Author:            Martin Pugh
				Twitter:           @thesurlyadm1n
				Spiceworks:        Martin9700
				Blog:              www.thesurlyadmin.com
			   
				Changelog:
				    2.0             New release uses Write-Progress for graphical display while couting
								    down.
				    1.0             Initial Release
			.LINK
				http://community.spiceworks.com/scripts/show/1712-start-countdown
			#>
		    Param(
			    [Int32]$Seconds = 10,
			    [string]$Message = "Pausing for 10 seconds..."
		    )
			ForEach ($Count in (1..$Seconds))
			{   
                Write-Progress -Id 1 -Activity $Message -Status "Waiting for $Seconds seconds, $($Seconds - $Count) left" -PercentComplete (($Count / $Seconds) * 100)
				Start-Sleep -Seconds 1
			}
			    Write-Progress -Id 1 -Activity $Message -Status "Completed" -PercentComplete 100 -Completed
		}

        Function CreateCheckPoint
        {
            <#
                .SYNOPSIS
                    Create Check point to Named Check point for VMs contain system name 
                .DESCRIPTION

                    To Test from PowerShell IDE use following command:
                    Import-Module -Name ".\CreateCheckPoint.ps1" -Force

                    CreateCheckPoint -SystemName "-System01" -CheckPointName '20191103_1430'

                .PARAMETER $SystemName
                    Name of System.
			        Each VM contain inside VM name that string.
                    Note:
                    !!!!!!!!!!
                    System Name MUST be last part of VM name
                    !!!!!!!!!!!

                .PARAMETER $CheckPointName
                    Check point name for selected VM inside entered System Name.
                    Note: 
                    !!!!!!!!!!
                    Each VM inside System name, must have the same check point name 
                    !!!!!!!!!! 

                .ExAMPLE
                    Create check point name '20191103_1430' for VMs inside system name "-System01"

			        CreateCheckPoint -SystemName "-System01" -CheckPointName '20191103_1430'

            #>
            [CmdletBinding()]  
            param
            (
                [parameter(Position=0,Mandatory=$true,HelpMessage="You must enter System Name")]
                [string]$SystemName="",

                [parameter(Position=1,Mandatory=$true,HelpMessage="You must enter check point name")]
                [string]$CheckPointName="",

                [parameter(Position=2)]
                [bool]$StopVMs=$true
            )
            BEGIN
            {
            }
  
            PROCESS
            {
		        #Remove-Module Hyper-V
		        #Import-Module Hyper-V -RequiredVersion 1.1

                Write-Output "Reading VM(s) from system: $SystemName"
                Write-Output "Reading VM(s) from system: $SystemName" | Out-File -FilePath $outLogFileName -Append

                $VMs=Get-SCVirtualMachine | Where {$_.Name -like "*$SystemName"} | Sort-Object -Property Name
                Write-Output "Start if need to removie DVD Media from VMs"
                Write-Output "Start if need to removie DVD Media from VMs" | Out-File -FilePath $outLogFileName -Append
                
                $RefreshError=$false

		        foreach ($VM in $VMs)
		        {
                    $continue=$true
                    Write-Output "Check DVD Media from VM: $VM ..."
                    Write-Output "Check DVD Media from VM: $VM ..." | Out-File -FilePath $outLogFileName -Append

                    $VMDrives = Get-SCVirtualDVDDrive -VM $VM

                    foreach ($VMDrive in $VMDrives)
                    {
                        if ($VMDrive.Connection -ne "None") 
                        {
	                        Write-Output "Removing ISO from" $($VMDrive.VMName)
                            Write-Output "Removing ISO from" $($VMDrive.VMName) | Out-File -FilePath $outLogFileName -Append

                            $DVDDrive = Get-SCVirtualDVDDrive -VM $VM
                            $result = Set-SCVirtualDVDDrive -VirtualDVDDrive $DVDDrive -Bus $VMDrives.Bus -LUN $VMDrives.Lun -NoMedia

		                    if (!$?) # Check if command executed successfully
		                    {
                                $continue=$false
                                Write-Error "ERROR - Removing ISO from $($VMDrive.VMName)"
                                Write-Error "Please, manually eject ISO file from VM: $($VMDrive.VMName)"
                                Write-Error "ERROR - Removing ISO from $($VMDrive.VMName)" | Out-File -FilePath $outLogFileName -Append
                                Write-Error "Please, manually eject ISO file from VM: $($VMDrive.VMName)" | Out-File -FilePath $outLogFileName -Append
                            }
                        }
                    }
                }

                if(!$continue)
                {
                    Write-Error "Please, manually eject DVD from VMs, check previous error message"
                    Write-Error "After thar, please start Create Checkpoint again !!!"
                    Write-Error "Please, manually eject DVD from VMs, check previous error message" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "After thar, please start Create Checkpoint again !!!" | Out-File -FilePath $outLogFileName -Append

                    return
                }

                # Power Off VMs
                if ($StopVMs)
                {
		            Write-Output "Power off VMs before create checkpoint ..."
                    Write-Output "Power off VMs before create checkpoint ..." | Out-File -FilePath $outLogFileName -Append
		            foreach ($VM in $VMs)
		            {
                        if($VM.Status -eq 'Running')
                        {
			                #Stop-VM -VMName $($VM.Name) -ComputerName $($VM.HostName)
                            $result=Stop-SCVirtualMachine -VM $VM -ErrorAction SilentlyContinue
                            if ($?)
                            {
    			                Write-Output "Stop-SCVirtualMachine -VM $($VM.Name)"
                                Write-Output "Stop-SCVirtualMachine -VM $($VM.Name)" | Out-File -FilePath $outLogFileName -Append

        		                Start-Countdown -Seconds 3 -Message "Sleep for 3 seconds ..."
                            }
                            else
                            {
    			                Write-Error "Error to Stop VM name: $($VM.Name)"
    			                Write-Error "Error to Stop VM name: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append

                                $RefreshError=$true
                            }
                        }
		            }
                }

		        foreach ($VM in $VMs)
                {
                    try
                    {
                        Write-Output "Start to created checkpoint for VM: $VM"
                        Write-Output "Start to created checkpoint for VM: $VM" | Out-File -FilePath $outLogFileName -Append

                        #Checkpoint-VM -Name $VM.Name -ComputerName $VM.VMHost.Name -SnapshotName $CheckPointName
                        $res=New-SCVMCheckpoint -VM $VM -Name $CheckPointName
                        if ($?)
                        {
                            Write-Output "successfully created checkpoint for VM:  $($VM.Name)"
                            Write-Output "successfully created checkpoint for VM:  $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
                        }
                        else
                        {
    			            Write-Error "Error to create checkpoint for VM name: $($VM.Name)"
    			            Write-Error "Error to create checkpoint for VM name: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
                            $RefreshError=$true
                        }

                    }
                    catch 
                    { 
                        Write-Error "`n"
                        Write-Error "ERROR creating Checkpoint for $VM.Name"
                        Write-Error "`n"
                        Write-Error "Checkpoint-VM -Name $VM.Name -ComputerName $VM.VMHost.Name -SnapshotName $CheckPointName"
                        Write-Error "`n"
                        Write-Error "Error message:"
                        Write-Error "======================================="
		                for($i=1; $i -le $error.Count; $i++)
		                {
                            Write-Error $error[$i]
                            Write-Error "----------------------------------------------------------------------------------"
                        }
                        Write-Error "`n"

                        Write-Error "`n" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "ERROR creating Checkpoint for $VM.Name" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "`n" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "Checkpoint-VM -Name $VM.Name -ComputerName $VM.VMHost.Name -SnapshotName $CheckPointName" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "`n" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "Error message:" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "=======================================" | Out-File -FilePath $outLogFileName -Append
		                for($i=1; $i -le $error.Count; $i++)
		                {
                            Write-Error $error[$i] | Out-File -FilePath $outLogFileName -Append
                            Write-Error "----------------------------------------------------------------------------------" | Out-File -FilePath $outLogFileName -Append
                        }
                        Write-Error "`n" | Out-File -FilePath $outLogFileName -Append


                        break
                    }
                }
            }
            END
            {
            }
        }

    }
    PROCESS
    {
        #cls
        if (-not (Get-Module -Name Hyper-V | Where {$_.Version -eq 1.1}) )
        {
            Remove-Module Hyper-V -ErrorAction SilentlyContinue
        } 
        Import-Module Hyper-V -RequiredVersion 1.1

        Import-Module BitsTransfer
        
        # check if path for parameter $BackupLocation exist
        if ($BackupLocation)
        {
            $CopyLocation=$BackupLocation+"\"+$CheckPointName
            if (-not (Test-Path $BackupLocation -PathType Container))
            {
                Write-Error "Backup folder: $BackupLocation, does not exist!" -ErrorAction Stop
                Write-Error "Backup folder: $BackupLocation, does not exist!" -ErrorAction Stop | Out-File -FilePath $outLogFileName -Append
                Break
            }
            else
            {
                # check if exist folder with name equal parameter $CheckPointName inside path equal $BackupLocation
                if (Test-Path $CopyLocation -PathType Container)
                {
                    Write-Error "Backup folder: [$BackupLocation\$CheckPointName], already exist, please change checkpoint name: [$CheckPointName] to new one" -ErrorAction Stop
                    Write-Error "Backup folder: [$BackupLocation\$CheckPointName], already exist, please change checkpoint name: [$CheckPointName] to new one" -ErrorAction Stop | Out-File -FilePath $outLogFileName -Append
                    Break
                }
                else
                {
                    New-Item -Path $BackupLocation -Name $CheckPointName -ItemType "directory" 
                    if ($?)
                    {
    			        Write-Output "Folder [$CopyLocation], to store shared HDD(s) successfully created"
                        Write-Output "Folder [$CopyLocation], to store shared HDD(s) successfully created" | Out-File -FilePath $outLogFileName -Append
                    }
                    else
                    {
    			        Write-Error "Error creating folder [$BackupLocation\$CheckPointName], to store shared HDD(s)"
                        Write-Error "Verify that the account under which the script was started has sufficient privileges to create a subfolder"
                        Write-Error "on [$ Backup Location]"
                        Write-Error "Fix it and run the script again!" -ErrorAction Stop

    			        Write-Error "Error creating folder [$BackupLocation\$CheckPointName], to store shared HDD(s)" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "Verify that the account under which the script was started has sufficient privileges to create a subfolder" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "on [$ Backup Location]" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "Fix it and run the script again!" -ErrorAction Stop | Out-File -FilePath $outLogFileName -Append

                        Break
                    }
                }
            }
        
            if ( ($BackupLocation.StartsWith('\\')) -and $BackupLocation.Contains('$'))
            {
                $BackupVolumeTmp=$BackupLocation.Split('$') 
                $BackupVolume=$BackupVolumeTmp[0].Substring($BackupVolumeTmp[0].Length-1)+ ":" + $BackupVolumeTmp[1] 
                $lastIndex=$BackupVolume.LastIndexOf('\')
                $BackupVolume=$BackupVolume.Substring(0, $lastIndex)

                $Tmp= $BackupVolumeTmp[0].Substring(2) 
                $Tmp= $Tmp.Substring(0,$Tmp.Length-2)
                $HostName= $Tmp 
            }
            else
            {
                $BackupVolume=$BackupLocation.Substring(0,3) 
                $HostName="localhost"
            }
        }

        $RefreshError=$false
        $VMs = $null
        Write-Output "Reading VM(s) from system: $SystemName"
        Write-Output "Reading VM(s) from system: $SystemName" | Out-File -FilePath $outLogFileName -Append

        #
        # Get all VM(s) from parameter $SystemName
        #
        $VMs = Get-SCVirtualMachine -VMMServer "localhost" | Where {$_.Name -like "*$SystemName"} | Sort-Object -Property Name
        $VMNum=$VMs.Count
        Write-Output "VM(s) number: $VMNum"
        Write-Output "VM(s) number: $VMNum" | Out-File -FilePath $outLogFileName -Append
        if ($VMs -eq $null)
        {
            Write-Warning 'Does NOT exist VM(s) with system name: [$SystemName]!' 
            Write-Warning 'Does NOT exist VM(s) with system name: [$SystemName]!' | Out-File -FilePath $outLogFileName -Append
            break
        }

        $isError=$false

        # Stop all VMs from $SystemName
        ForEach ($VM in $VMs)
        {
            Write-Output "Check if VM: $VM, is running ..."
            Write-Output "Check if VM: $VM, is running ..." | Out-File -FilePath $outLogFileName -Append

            if($VM.Status -eq 'Running')
            {
                $result=Stop-SCVirtualMachine -VM $VM -ErrorAction SilentlyContinue
                if ($?)
                {
    			    Write-Output "Stop-SCVirtualMachine -VM $($VM.Name)"
                    Write-Output "Stop-SCVirtualMachine -VM $($VM.Name)" | Out-File -FilePath $outLogFileName -Append

        		    Start-Countdown -Seconds 3 -Message "Sleep for 3 seconds ..."
                }
                else
                {
    			    Write-Error "Error to Stop VM name: $($VM.Name)"
    			    Write-Error "Error to Stop VM name: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
                    $RefreshError=$true
                }
            }
        }
        if ($RefreshError)
        {
  			Write-Output "Some VM(s) cannot be stopp. Manualy try to stop all VM(s) from the system: [$SystemName]"
            Write-Output "Some VM(s) cannot be stopp. Manualy try to stop all VM(s) from the system: [$SystemName]" | Out-File -FilePath $outLogFileName -Append

            break
        }

        # remove mounted ISO file from VM(s)
        ForEach ($VM in $VMs)
        {
            Write-Output "Check DVD Media for VM: $VM ..."
            Write-Output "Check DVD Media for VM: $VM ..." | Out-File -FilePath $outLogFileName -Append

            $continue=$true
            $VMDrives = Get-SCVirtualDVDDrive -VM $VM
            foreach ($VMDrive in $VMDrives)
            {
                #if ($VMDrive.DvdMediaType -eq "ISO") 
                if ($VMDrive.Connection -ne "None") 
                {
	                Write-Output "Removing ISO from" $($VMDrive.VMName)
                    Write-Output "Removing ISO from" $($VMDrive.VMName) | Out-File -FilePath $outLogFileName -Append

                    $DVDDrive = Get-SCVirtualDVDDrive -VM $VM
                    $result = Set-SCVirtualDVDDrive -VirtualDVDDrive $DVDDrive -Bus $VMDrives.Bus -LUN $VMDrives.Lun -NoMedia

		            if (!$?) # Check if command executed successfully
		            {
                        $continue=$false
                        Write-Error "ERROR - Removing ISO from $($VMDrive.VMName)"
                        Write-Error "Please, manually eject ISO file from VM: $($VMDrive.VMName)"

                        Write-Error "ERROR - Removing ISO from $($VMDrive.VMName)" | Out-File -FilePath $outLogFileName -Append
                        Write-Error "Please, manually eject ISO file from VM: $($VMDrive.VMName)" | Out-File -FilePath $outLogFileName -Append
                    }
                }
            }
            if(!$continue)
            {
                Write-Error "Please, manually eject DVD from VMs, check previous error message"
                Write-Error "After that, please start script CreateCheckPoint again !!!"

                Write-Error "Please, manually eject DVD from VMs, check previous error message" | Out-File -FilePath $outLogFileName -Append
                Write-Error "After that, please start script CreateCheckPoint again !!!" | Out-File -FilePath $outLogFileName -Append

                return
            }
        }

        # Refresh all VMs from $SystemName
        $RefreshError=$false
        ForEach ($VM in $VMs)
        {
            Write-Output "Refresh VM: $VM ..."
            Write-Output "Refresh VM: $VM ..." | Out-File -FilePath $outLogFileName -Append

            $result = Read-SCVirtualMachine -VM $VM
            #MostRecentTaskUIState               : Completed
            if ($result.MostRecentTaskUIState -ne 'Completed') # mora biti zadnji refresh u statusu 'Completed'
            {
                Write-Warning "Error to refresh VM: [$($VM.Name)]"
                Write-Warning "Error to refresh VM: [$($VM.Name)]" | Out-File -FilePath $outLogFileName -Append
                $RefreshError=$true
            }
        }

        if ($RefreshError)
        {
		    Write-Output "Some VM(s) cannot be refresh. Manualy try to refresh all VM(s) from the system: [$SystemName]"
            Write-Output "Some VM(s) cannot be refresh. Manualy try to refresh all VM(s) from the system: [$SystemName]" | Out-File -FilePath $outLogFileName -Append

            break 
        }

        # Get information about shared HDD(s) on VM(s)
        # !!! Put breakpoint here !!!
        $VDDs = @()
        $ShareHDDLocation = @()
        $ShareHDDLocBack = @()
        $SharedVHDSizeTotal=0
        $VMSharedHDDs = @()
        ForEach ($VM in $VMs)
        {
            Write-Output "Check if shared HDD exist on VM: $VM ..."
            Write-Output "Check if shared HDD exist on VM: $VM ..." | Out-File -FilePath $outLogFileName -Append
            
			# !!! Put breakpoint here !!!
            $HDDs=Get-VMHardDiskDrive -VMName $VM.Name -ControllerType SCSI -ComputerName $VM.HostName | where {($_.SupportPersistentReservations -eq $true)} | Select *
            ForEach($HDD in $HDDs)
            {
                Write-Output "Get VirtDiskDrive for VM: $VM.Name ..."
                Write-Output "Get VirtDiskDrive for VM: $VM.Name ..." | Out-File -FilePath $outLogFileName -Append

				# !!! Put breakpoint here !!!
                $VirtDiskDrive = @(Get-SCVirtualDiskDrive -VM $VM | Where-Object {([int]$_.Bus -eq [int]$HDD.ControllerNumber) -and `
                                   ([int]$_.Lun -eq [int]$HDD.ControllerLocation) -and `
                                   ($HDD.Path -like '*'+$_.VirtualHardDisk+'*' )})
                if ($VirtDiskDrive.Count -gt 0)
                {
                    $VirtDiskDriveID=$VirtDiskDrive.VirtualHardDiskId
                    $HDDData = $VM.VirtualHardDisks | Where {$_.ID -eq $VirtDiskDriveID}

                    #$HDDSize = $HDDData.Size/1024/1024/1024
                    $HDDSize = $HDDData.Size/1GB
                    #$HDDLocationPath=$HDDData.Location
					# Diskonect disks are done first, and before removing the disk, the name of the VM and the location of the shared HDDs are saved in the file
                    # Checking the Path property
                    # Path: C:\ClusterStorage\volume12\VM01\sqldtc.vhdx
                    #
                    $VDDs+=$VirtDiskDrive # moraju se dodati shared hdd i sa hist1 i sa hist2
                    if ($VMSharedHDDs.VMId -notcontains $VM.VMId) # for storing data for servers that have a shared hdd on them
                    {
                        $VMSharedHDDs+=$VM
                    }

                    #$ShareHDDLocBack+=@{VMName=$VM.Name;HostName=$VM.HostName;SharedHDDLoc=$HDD.Path;HDDSize=$HDDSize}
                    $ShareHDDLocBack+=@{VMName=$VM.Name;
                                        HostName=$VM.HostName;
                                        SharedHDDLoc=$HDD.Path;
                                        HDDSize=$HDDSize;
                                        ControllerNumber=$HDD.ControllerNumber;
                                        ControllerLocation=$HDD.ControllerLocation}

					# !!!
                    # all hdds should be added while checking that the shared hdd path has already been added - it must be sort at the beginning
                    # by vm names. In this way, when the shared hdd path is added on the first node, it already exists
                    # so the same path on the other node should not be added
                    # then at the end all hdds in the array are copied
                    # !!!
					 
                    [string]$object=$ShareHDDLocation | Where-Object {$_.SharedHDDLoc -eq $HDD.Path}
                    if (([string]$object -eq "") ) # VEC postoji
                    {
                        $SizeHDD=[math]::round($HDDData.Size/1GB, 2)
                        $ShareHDDLocation+=@{VMName=$VM.Name;
                                             HostName=$VM.HostName;
                                             SharedHDDLoc=$HDD.Path;
                                             HDDSize=$HDDSize;
                                             ControllerNumber=$HDD.ControllerNumber;
                                             ControllerLocation=$HDD.ControllerLocation;
                                             SizeHDD=$SizeHDD}
                        $SharedVHDSizeTotal+=$HDDSize
                    }
                }
            }
        }

        # !!! Put breakpoint here !!!
        if ($ShareHDDLocBack.Count -ne 0)
        {
            $ShareHDDLocBack | Format-Table
            $ShareHDDLocBack | Format-Table | Out-File -FilePath $outLogFileName -Append
        }

        # script didn`t detect any shared HDD, but parameter for [BackupLocation] location is provide
        # !!! Put breakpoint here !!!
        if ($BackupLocation -and ($ShareHDDLocBack.Count -eq 0))
        {
            $title    = "WARNING"
            $question = "Script did not detect any shared HDD, but parameter for [BackupLocation] location is provided. Are you sure you want to continue?"
            $choices  = "&Yes", "&No"

            $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
            if ($decision -eq 0) {
                Write-Warning "`nWARNING !!! Script continue without backup of shared HDD(s) ...`n"
                Write-Warning "`nWARNING !!! Script continue without backup of shared HDD(s) ...`n" | Out-File -FilePath $outLogFileName -Append
            } else {
                Write-Error "`nScript terminate, because did not detect any shared HDD.`nPlease eject all mounted ISO file(s) and manualy refres all VM(s), then try to start script again!!!`n"
                Write-Error "`nScript terminate, because did not detect any shared HDD.`nPlease eject all mounted ISO file(s) and manualy refres all VM(s), then try to start script again!!!`n" | Out-File -FilePath $outLogFileName -Append
                break
            }
        }

        # !!! Put breakpoint here !!!
        if ((-not $BackupLocation) -and ($ShareHDDLocBack.Count -gt 0))
        {
            Write-Output "Shared HDD exist of sistem. You MUST provide value for parameter [BackupLocation], where shared HDD(s) will be backup."
            Write-Output "Shared HDD exist of sistem. You MUST provide value for parameter [BackupLocation], where shared HDD(s) will be backup." | Out-File -FilePath $outLogFileName -Append

            break 
        }

        #
        # Check free space to copy shared VHD to backup location. Backup location is local HDD volume or cluster shared volume
        #
        # !!! Put breakpoint here !!!
        if ($ShareHDDLocation.Count -gt 0)
        {
            Write-Output "Check free space to copy shared VHD to backup location ..."
            Write-Output "Check free space to copy shared VHD to backup location ..." | Out-File -FilePath $outLogFileName -Append

            $isBackupFreeSpaceOK=$false

			# before removing, check if there is enough space in the location where the shared HDD should be saved
            # if there is enough space it continues, if there is not then throw out the message 'There is not enough space to copy shared VHD files' and stop
			# $DiskVolumesForHost=Get-SCVMHost -ComputerName $HostName

            #$BackupLocation="\\server01\ClusterStorage\Volume2\Backup_System01"
            # If the first two characters are '\\' and there is a $ in the backup location path
            # Remote location => compname=server01, folder=c$\ClusterStorage\Volume2\Backup_System01 (C:\ClusterStorage\Volume2\Backup_System01)
            # $BackupVolume='C:\ClusterStorage\Volume2'

            # $BackupLocation="c:\ClusterStorage\Volume2\Backup_System01"
            # If the first two characters are NOT '\\' and there is NO $ in the backup location path
            # Local location => folder=c:\ClusterStorage\Volume2\Backup_System01
            # $BackupVolume='C:\'
			 
            $DiskVolumesForHost=Get-SCVMHost -ComputerName $HostName
            $HDDName = $DiskVolumesForHost.DiskVolumes| Where { $_.Name -eq $BackupVolume}

            #$Capacity=$HDDName.Capacity/1024/1024/1024
	        #$FreeSpace=$HDDName.FreeSpace/1024/1024/1024
            $Capacity=$HDDName.Capacity/1GB
	        $FreeSpace=$HDDName.FreeSpace/1GB

            Write-Output "Free space [$FreeSpace] GB on host [$HostName]"
            Write-Output "Free space [$FreeSpace] GB on host [$HostName]" | Out-File -FilePath $outLogFileName -Append

            if ($SharedVHDSizeTotal -lt $FreeSpace)
            {
                $isBackupFreeSpaceOK=$true
            }

            if ($isBackupFreeSpaceOK)
            {
                #
                # !!! Remove shared VHD from VM(s)
                #
                ForEach ($VDD in $VDDs)
                {
                    $hddPath=$($VDD.VirtualHardDisk.SharePath)
                    $vmName=$($VDD.Name)

                    Write-Output "Removing shared VHD: [$hddPath] from VM: [$vmName]"
                    Write-Output "Removing shared VHD: [$hddPath] from VM: [$vmName]" | Out-File -FilePath $outLogFileName -Append

					# !!! Put breakpoint here !!!
                    $result = Remove-SCVirtualDiskDrive -VirtualDiskDrive $VDD -SkipDeleteVHD -Force
                    if ($?)
                    {
    			        Write-Output "successfully Remove-SCVirtualDiskDrive from [$vmName] name [$hddPath]"
                        Write-Output "successfully Remove-SCVirtualDiskDrive from [$vmName] name [$hddPath]" | Out-File -FilePath $outLogFileName -Append
                    }
                    else
                    {
        			    Write-Error "Error Remove-SCVirtualDiskDrive from [$vmName] name [$hddPath]"
        			    Write-Error "Error Remove-SCVirtualDiskDrive from [$vmName] name [$hddPath]" | Out-File -FilePath $outLogFileName -Append
                    }
                }
            }
            else
            {
                Write-Warning "There is NOT enought free space [$SharedVHDSizeTotal] GB to store shared HDD(s) from VM(s)."
                Write-Warning "Make enought free space [$SharedVHDSizeTotal] GB on host [$HostName] or choose another location with enought free space to store shared HDD(s) from VM(s)."
                Write-Warning "There is NOT enought free space [$SharedVHDSizeTotal] GB to store shared HDD(s) from VM(s)." | Out-File -FilePath $outLogFileName -Append
                Write-Warning "Make enought free space [$SharedVHDSizeTotal] GB on host [$HostName] or choose another location with enought free space to store shared HDD(s) from VM(s)." | Out-File -FilePath $outLogFileName -Append

                break 
            }
            #---------------------------------------------------------------
            # refresh data 
            # !!! Put breakpoint here !!!
            ForEach ($VM in $VMSharedHDDs)
            {
                Write-Output "Refres VM: $VM.VMName, after removed shared HDD(s) ..."
                Write-Output "Refres VM: $VM.VMName, after removed shared HDD(s) ..." | Out-File -FilePath $outLogFileName -Append

                $result = Read-SCVirtualMachine -VM $VM
                if ($?)
                {
    			    Write-Output "successfully refresh VM: $VM"
                    Write-Output "successfully refresh VM: $VM" | Out-File -FilePath $outLogFileName -Append
                }
                else
                {
    			    Write-Warning "ERROR refresh VM: $VM"
    			    Write-Warning "ERROR refresh VM: $VM" | Out-File -FilePath $outLogFileName -Append
                }

            }
            #---------------------------------------------------------------
            #
            # !!! Copy shared VHD to backup location
            #
            # !!! Put breakpoint here !!!
            ForEach ($SharedHDD in $ShareHDDLocation)
            {
                $sourecFileName = $SharedHDD.SharedHDDLoc.Replace(':','$')
                $sourecFileName = "\\"+$SharedHDD.HostName+"\"+$sourecFileName

                $TmpBackupLocation=$CopyLocation+"\"+$SharedHDD.VMName

                # check if destination backup folder exist, if NOT exist create it
                if (-not (Test-Path $TmpBackupLocation -PathType Container))
                {
                    New-Item -ItemType "directory" -Path $TmpBackupLocation
                } 

                Write-Output "`nCopy: $($sourecFileName), size: [$($SharedHDD.SizeHDD)]GB to: $($TmpBackupLocation)"
                Write-Output "`nCopy: $($sourecFileName), size: [$($SharedHDD.SizeHDD)]GB to: $($TmpBackupLocation)" | Out-File -FilePath $outLogFileName -Append

                # !!! Put breakpoint here !!!
                Start-BitsTransfer -Source $sourecFileName -Destination $TmpBackupLocation `
                                   -Description "To Destination: [$TmpBackupLocation]" `
                                   -DisplayName "Backup [$sourecFileName], Size:[$($SharedHDD.SizeHDD)]GB"

                Write-Output "`nCopy completed: $($sourecFileName), to: $($TmpBackupLocation)"
                Write-Output "`nCopy completed: $($sourecFileName), to: $($TmpBackupLocation)" | Out-File -FilePath $outLogFileName -Append
            }        
        }

        $VDDs = @()
        #---------------------------------------------------------------------------------

        # Create new check point for all VM(s) inside system name
        # !!! Put breakpoint here !!!
        CreateCheckPoint -SystemName $SystemName -CheckPointName $CheckPointName

        #---------------------------------------------------------------------------------

        #
        # !!! Add shared HDD(s) to VM(s) after checkpoint has been created
        #
        # !!! Put breakpoint here !!!
        if ($ShareHDDLocation.Count -gt 0)
        {
            # After created new chaeckpoint add shared hdd back to VM(s)

            Write-Output 'After created new checkpoint add shared hdd back to VM(s)'
            Write-Output 'After created new checkpoint add shared hdd back to VM(s)' | Out-File -FilePath $outLogFileName -Append
 
            ForEach($ShareHDD in $ShareHDDLocBack)
            {
                Write-Output "Add shared HDD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]"
                Write-Output "Add shared HDD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]" | Out-File -FilePath $outLogFileName -Append
                
                # !!! Put breakpoint here !!!
                $result=Add-VMHardDiskDrive -ComputerName $ShareHDD.HostName -ControllerType SCSI -ControllerNumber $ShareHDD.ControllerNumber `
                        -ControllerLocation $ShareHDD.ControllerLocation -Path $ShareHDD.SharedHDDLoc -AllowUnverifiedPaths `
                        -VMName $ShareHDD.VMName -SupportPersistentReservations -ErrorAction SilentlyContinue

                if ($?)
                {
    			    Write-Output "successfully added shared VHD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]"
                    Write-Output "successfully added shared VHD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]" | Out-File -FilePath $outLogFileName -Append
                }
                else
                {
    			    Write-Error "ERROR add shared VHD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]"
       			    Write-Error "Please, manually add shared VHD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)] !!!"
                    Write-Error ""
                    Write-Error "Executed command:"
                    $cmdText= "Add-VMHardDiskDrive -VMName " + $ShareHDD.VMName + " -ControllerType SCSI -ControllerNumber " + $ShareHDD.ControllerNumber.ToString() +" "+ `
                        "-ControllerLocation " + $ShareHDD.ControllerLocation.ToString() + " -Path " + $ShareHDD.SharedHDDLoc +`
                        " -AllowUnverifiedPaths -ComputerName " + $ShareHDD.HostName + " -SupportPersistentReservations"
                    Write-Error $cmdText

    			    Write-Error "ERROR add shared VHD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]" | Out-File -FilePath $outLogFileName -Append
       			    Write-Error "Please, manually add shared VHD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)] !!!" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "Executed command:" | Out-File -FilePath $outLogFileName -Append
                    Write-Error $cmdText | Out-File -FilePath $outLogFileName -Append
                }
            }
        }

        # refresh ALL VMs from $SystemName
        # !!! Put breakpoint here !!!
        ForEach ($VM in $VMs)
        {
            Write-Output "Refresh data for VM: $($VM.Name)"
            Write-Output "Refresh data for VM: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append

            $result = Read-SCVirtualMachine -VM $VM
            if ($?)
            {
    			Write-Output "successfully refresh VM: $VM"
                Write-Output "successfully refresh VM: $VM" | Out-File -FilePath $outLogFileName -Append
            }
            else
            {
    			Write-Warning "ERROR refresh VM: $VM"
    			Write-Warning "ERROR refresh VM: $VM" | Out-File -FilePath $outLogFileName -Append
            }
        }

        Remove-Module BitsTransfer
        Remove-Module Hyper-V
        Import-Module Hyper-V
    }
    END
    {
        $date = Get-Date -Format yyyy-MM-dd
        $time = get-date -Format HH:mm:ss
        $datetime = $date + "|" + $time
        $EndDate=Get-Date

        Write-Output "`nFinish CreateCheckPoint [$CheckPointName] ...`nEnd time [$datetime]`n"
        Write-Output "`nFinish CreateCheckPoint [$CheckPointName] ...`nEnd time [$datetime]`n" | Out-File -FilePath $outLogFileName -Append

        New-TimeSpan –Start $StartDate –End $EndDate
   }
}