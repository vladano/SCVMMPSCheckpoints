Function RestoreCheckPoint
{
    <#
        .SYNOPSIS
            Restore named check point for VM(s) contain system name (parameter SystemName).

        .DESCRIPTION
            Restore named check point for VM(s) contain system name (parameter SystemName).

            If VM(s) contain shared HDD, you need to provide backupe location with enough free space to backup all 
            shared HDD(s) from all VM(s) inside system name (parameter SystemName).

            To Test from PowerShell IDE use following command:
            Import-Module -Name ".\RestoreCheckPoint.ps1" -Force

            RestoreCheckPoint  -SystemName "-TrainingSystem01" -CheckPointName "workgroup"
            
            or

            RestoreCheckPoint  -SystemName "-TrainingSystem01" -CheckPointName "20191217" -BackupLocation "\\hs2hv8\c$\ClusterStorage\Volume2\TrainingSystem01_Backup"

        .PARAMETER $SystemName
            Name of System.
			Each VM contain inside VM name that string.
            Note:
            System Name MUST be last part of VM name

        .PARAMETER $CheckPointName
            Check point name for selected VM inside entered System Name.
            Note: 
            Each VM inside System name, must have the same check point name 

        .PARAMETER $BackupLocation
            Full path of folder to store shared VHD file(s) if exist(s)

        .ExAMPLE
            Restore check point name 'workgroup' for VMs inside system name "-TrainingSystem01"
            NOTE:
            System without shared HDD(s)

			RestoreCheckPoint  -SystemName "-TrainingSystem01" -CheckPointName "workgroup"

        .ExAMPLE
            Restore check point name '20191217' for VMs inside system name "-TrainingSystem01" and if exist shared vhds copy to location "\\hs2hv8\c$\ClusterStorage\Volume2\TrainingSystem01_Backup"
            NOTE:
            System contain shared HDD(s)

			RestoreCheckPoint  -SystemName "-TrainingSystem01" -CheckPointName "20191217" -BackupLocation "\\hs2hv8\c$\ClusterStorage\Volume2\TrainingSystem01_Backup"

        .NOTES
            Author: Vladan Obradovic
            Last Edit: 28.08.2020 DD/MM/YYYY
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
            Version 2.4 - 2020-10-07
                          Added output log messages to file inside .\Log folder 
                          List shared HDD information inside console and write that data to log messages file inside .\Log folder 
            Version 2.5 - 2020-11-03
                          Add file size to display when copy file from backup location to original location  
            Version 2.6 - 2020-12-11
                          Bug fix write to log file and display the size of the file being copied
            Version 2.7 - 2021-04-09
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

        Write-Output "`nStart time [$datetime]`nStarting RestoreCheckPoint ..."
        Write-Output "`nStart time [$datetime]`nStarting RestoreCheckPoint ..." | Out-File -FilePath $outLogFileName -Append

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

        Function RestoreCheckPoint
        {
            <#
                .SYNOPSIS
                    Restore Check point to Named Check point for VM kontaining system name 
                .DESCRIPTION

                    To Test from PowerShell IDE use following command:
                    Import-Module -Name ".\RestoreCheckPoint.ps1" -Force

                    RestoreCheckPoint -SystemName "System01" -CheckPointName 'System01 - (11/24/2016 15:06:31)'

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
                    Restore check point name 'System01 - (11/24/2016 15:06:31)' for VMs inside system name "System01"

			        RestoreCheckPoint -SystemName "System01" -CheckPointName 'System01 - (11/24/2016 15:06:31)'

                .ExAMPLE
                    Restore check point name 'System01 - (11/24/2016 15:06:31)' for VMs inside system name "System01" and Power on VMs

			        RestoreCheckPoint -SystemName "System01" -CheckPointName 'System01 - (11/24/2016 15:06:31)' -StartVMs $true

                .ExAMPLE
                    Restore first check point for VMs inside system name "-System01"

			        RestoreCheckPoint -SystemName "-System01" -RestoreFirstCheckPoint

                .ExAMPLE
                    Restore first check point for VMs inside system name "System01" and Power on VMs

			        RestoreCheckPoint -SystemName "-System01" -RestoreFirstCheckPoint -StartVMs $true
            #>
            [CmdletBinding()]  
            param
            (
                [parameter(ParameterSetName="CheckPointName",Position=0,Mandatory=$true,HelpMessage="You must enter System Name")]
                [parameter(ParameterSetName="FirstCheckPoint",Position=0,Mandatory=$true,HelpMessage="You must enter System Name")]
                [string]$SystemName="",

                [parameter(ParameterSetName="CheckPointName",Position=1,Mandatory=$true,HelpMessage="You must enter check point name")]
                [string]$CheckPointName="",

                [parameter(ParameterSetName="FirstCheckPoint",Position=1,Mandatory=$true)]
                [switch]$RestoreFirstCheckPoint=$true,

                [parameter(ParameterSetName="CheckPointName",Position=2)]
                [parameter(ParameterSetName="FirstCheckPoint",Position=2)]
                [bool]$StartVMs=$false
            )
            BEGIN
            {
                Write-Output "Starting Restore CheckPoint ..."
                Write-Output "Starting Restore CheckPoint ..." | Out-File -FilePath $outLogFileName -Append
            }
  
            PROCESS
            {
                $VMs=Get-SCVirtualMachine | Where {$_.Name -like "*$SystemName"} | Sort-Object -Property Name
		        foreach ($VM in $VMs)
		        {
                    if ($CheckPointName -ne "")
                    {
                        $CheckPointData=Get-SCVMCheckpoint -VM $VM

                        if ($CheckPointData)
                        {
							$isExistCheckPointName=$false
							foreach ($CheckPoint in $CheckPointData)
							{
								If ($CheckPoint.Name -eq $CheckPointName)
								{
									$isExistCheckPointName=$true

									Write-Output "Starting action Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name), please wait .."
                                    Write-Output "Starting action Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name), please wait .." | Out-File -FilePath $outLogFileName -Append
          
									# restore existing checkpoint
									$result=Restore-SCVMCheckpoint -VMCheckpoint $CheckPoint
									if ($?)
									{
										Write-Output "successfully Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name)"
                                        Write-Output "successfully Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
									}
									else
									{
										Write-Error "ERROR Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name)"
                                        Write-Error "ERROR Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
									}
									break # foreach
								}
							}
							if (-not $isExistCheckPointName)
							{
								Write-Warning "Checkpoint name: $CheckPointName does NOT exist on VM: $($VM.Name) on host: $($VM.HostName) !!!"
                                Write-Warning "Checkpoint name: $CheckPointName does NOT exist on VM: $($VM.Name) on host: $($VM.HostName) !!!" | Out-File -FilePath $outLogFileName -Append
							}
                        }
                        else
                        {
			                Write-Warning "Checkpoint(s) does NOT exist on VM: $($VM.Name) on host: $($VM.HostName) !!!"
                            Write-Warning "Checkpoint(s) does NOT exist on VM: $($VM.Name) on host: $($VM.HostName) !!!" | Out-File -FilePath $outLogFileName -Append
                        }
                    }
                    else # restore last checkpoint name per VM
                    {
                        $CheckPointData=Get-SCVMCheckpoint -VM $VM -MostRecent

                        foreach ($CPData in $CheckPointData)
		                {
                            if ($CPData.ParentSnapshotName -eq $null)
                            {
                                $CheckPointNameFirst=$($CPData.Name)
                                
 			                    Write-Output "Starting action Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name), please wait ..."
                                Write-Output "Starting action Restore-SCVMCheckpoint name $CheckPointName for VM: $($VM.Name), please wait ..." | Out-File -FilePath $outLogFileName -Append

                                $result=Restore-SCVMCheckpoint -VMCheckpoint $CheckPointData
                                if ($?)
                                {
    			                    Write-Output "successfully Restore-SCVMCheckpoint name $CheckPointNameFirst for VM: $($VM.Name)"
                                    Write-Output "successfully Restore-SCVMCheckpoint name $CheckPointNameFirst for VM: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
                                }
                                else
                                {
    			                    Write-Error "ERROR Restore-SCVMCheckpoint name $CheckPointNameFirst for VM: $($VM.Name)"
                                    Write-Error "ERROR Restore-SCVMCheckpoint name $CheckPointNameFirst for VM: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append
                                }

                                #Start-Countdown -Seconds 2 -Message "Sleep for 2 seconds ..."
                                break
                            }
                        }
                    }
		        }

                if ($StartVMs)
                {
		            foreach ($VM in $VMs)
		            {
                        $VMPowerStatus=Start-SCVirtualMachine -VM $VM
                        if ($VMPowerStatus.VirtualMachineState -eq "Running")
                        {
			                Write-Output "VM: $($VM.Name) successfully started ..."
                            Write-Output "VM: $($VM.Name) successfully started ..." | Out-File -FilePath $outLogFileName -Append

			                Start-Sleep -s 3
                        }
                        else
                        {
			                Write-Warning "ERROR starting VM: $($VM.Name) !!!"
                            Write-Warning "ERROR starting VM: $($VM.Name) !!!" | Out-File -FilePath $outLogFileName -Append
                        }
		            }
                }
           }
            END
            {
                Write-Output "Ending RestoreCheckPoint ..."
                Write-Output "Ending RestoreCheckPoint ..." | Out-File -FilePath $outLogFileName -Append
            }
        }

    }
    PROCESS
    {
        if (-not (Get-Module -Name Hyper-V | Where {$_.Version -eq 1.1}) )
        {
            Remove-Module Hyper-V -ErrorAction SilentlyContinue
        }

        Import-Module Hyper-V -RequiredVersion 1.1

        Import-Module BitsTransfer

        # Backup location has folder(s) where shared hdd(s) file(s) has copied
        # check if backup location exist (shared hdd(s) previously stored to this location )
        if ($BackupLocation)
        {
            $CopyLocation=$BackupLocation+"\"+$CheckPointName
            if (-not (Test-Path $BackupLocation -PathType Container))
            {
                Write-Error 'Backup folder: $BackupLocation, does not exist!'
                Write-Error 'Backup folder: $BackupLocation, does not exist!' | Out-File -FilePath $outLogFileName -Append
                break
            }
            else
            {
                # check if there is a subfolder with the name checkpoint
                if (-not (Test-Path $CopyLocation -PathType Container))
                {
                    Write-Warning 'Checkpoint folder: [$BackupLocation+"\"+$CheckPointName], does not exist!'
                    Write-Warning 'Checkpoint folder: [$BackupLocation+"\"+$CheckPointName], does not exist!' | Out-File -FilePath $outLogFileName -Append
                    break
                }
            }

            if ( ($BackupLocation.StartsWith('\\')) -and $BackupLocation.Contains('$'))
            {
                $BackupVolumeTmp=$BackupLocation.Split('$') # "\\server01\share","\ClusterStorage\Volume2\VM01_Backup"
                $BackupVolume=$BackupVolumeTmp[0].Substring($BackupVolumeTmp[0].Length-1)+ ":" + $BackupVolumeTmp[1] # "C" +":" + "\ClusterStorage\Volume2\VM01_Backup"
                $lastIndex=$BackupVolume.LastIndexOf('\')
                $BackupVolume=$BackupVolume.Substring(0, $lastIndex)

                $Tmp= $BackupVolumeTmp[0].Substring(2) # "server01\c"
                $Tmp= $Tmp.Substring(0,$Tmp.Length-2)
                $HostName= $Tmp # "server01"
            }
            else
            {
                $BackupVolume=$BackupLocation.Substring(0,3) # $BackupLocation='C:\ClusterStorage\Volume2' => $BackupVolume='C:\'
                $HostName="localhost"
            }
        }

        $VMs = $null

        Write-Output "Reading VM(s) from system: $SystemName"
        Write-Output "Reading VM(s) from system: $SystemName" | Out-File -FilePath $outLogFileName -Append

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

        #
        # Checking if shared HDD exist on VM
        #
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
            
            $HDDs=Get-VMHardDiskDrive -VMName $VM.Name -ControllerType SCSI -ComputerName $VM.HostName | where {($_.SupportPersistentReservations -eq $true)} | Select *
            ForEach($HDD in $HDDs)
            {
                $HDDNames=@()
                $HDDNames=$($HDD.Path).Split('\')
                $HDDFileName=$HDDNames[$HDDNames.Count – 1]
                
                Write-Output "Get data for VirtDiskDrive [$HDDFileName] from VM: $($VM.Name) ..."
                Write-Output "Get data for VirtDiskDrive [$HDDFileName] from VM: $($VM.Name) ..." | Out-File -FilePath $outLogFileName -Append
    
                $VirtDiskDrive = @(Get-SCVirtualDiskDrive -VM $VM | Where-Object {([int]$_.Bus -eq [int]$HDD.ControllerNumber) -and `
                                    ([int]$_.Lun -eq [int]$HDD.ControllerLocation) -and `
                                    ($HDD.Path -like '*'+$_.VirtualHardDisk+'*' )})

                if ($VirtDiskDrive.Count -gt 0)
                {
                    $VirtDiskDriveID=$VirtDiskDrive.VirtualHardDiskId
                    $HDDData = $VM.VirtualHardDisks | Where {$_.ID -eq $VirtDiskDriveID}
                    
                    #$HDDSize = $HDDData.Size/1024/1024/1024
                    #$HDDSize
                    $HDDSize = $HDDData.Size/1GB

                    $VDDs+=$VirtDiskDrive # shared hdd must be added with both VMSQL01 and VMSQL02
                    if ($VMSharedHDDs.VMId -notcontains $VM.VMId) # for storing data for servers that have a shared hdd on them
                    {
                        $VMSharedHDDs+=$VM
                    }

                    $PrimaryVMName=$VM.Name
                    $SharedOrigHDDLoc = $HDD.Path.Replace(':','$')
                    $SharedOrigHDDLoc = "\\"+$HDD.ComputerName+"\"+$SharedOrigHDDLoc

                    $object=$ShareHDDLocBack | Where-Object {$_.SharedHDDLoc -eq $HDD.Path}
                    if ($object -ne $null) # Already exists
                    {
                        $PrimaryVMName=$object.PrimaryVMName
                        $SharedOrigHDDLoc=""
                    }

                    $SizeHDD=[math]::round($HDDData.Size/1GB, 2)

					$ShareHDDLocBack+=@{VMName=$VM.Name; # name of the VM
                                        HostName=$VM.HostName; # the host on which the VM resides
                                        SharedHDDLoc=$HDD.Path; # path to the shared HDD on the VM
                                        SharedOrigHDDLoc=$SharedOrigHDDLoc; # UNC path to the shared HDD on the VM (this is set at the first node)
                                        SharedBckHDDLoc=""; # UNC path of dp backup location of shared hdd (this is set at the first node)
                                        PrimaryVMName=$PrimaryVMName; # primary VM name (this is set on the first node)                                        
										ControllerNumber=$HDD.ControllerNumber;
                                        ControllerLocation=$HDD.ControllerLocation;
                                        SizeHDD=$SizeHDD}
                }
            }
        }

        # !!! Put breakpoint here !!!
        # if you have shared hdds on sistem and if $ShareHDDLocBack.Count == 0, stop script, refresh VMs and start again
        if ($ShareHDDLocBack.Count -ne 0) 
        {
            Write-Output "`nNumber of shared HDDs:$($ShareHDDLocBack.Count)`n"
        }
        if ($ShareHDDLocBack.Count -ne 0) 
        {
            $ShareHDDLocBack | Format-Table
            $ShareHDDLocBack | Format-Table | Out-File -FilePath $outLogFileName -Append
        }

        # script didn`t detect any shared HDD, but parameter for [BackupLocation] location is provide
        # !!! Put breakpoint here !!!
        # if you have shared hdds on sistem and if $ShareHDDLocBack.Count == 0, stop script, refresh VMs and start again
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
        # if you have shared hdds on sistem and if $ShareHDDLocBack.Count == 0, stop script, refresh VMs and start again
        if ((-not $BackupLocation) -and ($ShareHDDLocBack.Count -gt 0))
        {
            Write-Warning "Shared HDD exist of VM(s). You MUST provide value for parameter [BackupLocation], from where shared HDD(s) will be resored."
            Write-Warning "Shared HDD exist of VM(s). You MUST provide value for parameter [BackupLocation], from where shared HDD(s) will be resored." | Out-File -FilePath $outLogFileName -Append
            break
        }

        # !!! Put breakpoint here !!!
        if ($BackupLocation)
        {
            if ($ShareHDDLocBack.Count -gt 0)
            {
                if ( ($BackupLocation.StartsWith('\\')) -and $BackupLocation.Contains('$'))
                {
                    $dirNames=Get-ChildItem -Path $CopyLocation -Directory

                    if ($dirNames.Count -gt 0)
                    {
                        # directory list (corresponding to a pair of VMs with shared HDD)
                        ForEach ($dir in $dirNames)
                        {
                            # list of files inside the directory (corresponding to a pair of VMs with shared HDD)
                            $sharedHDDNames=Get-ChildItem -Path $dir.FullName -File -Force -ErrorAction SilentlyContinue | Select-Object FullName
                            ForEach ($sharedHDDName in $sharedHDDNames)
                            {
                                $BckFullPath=$sharedHDDName.FullName

                                $BckFullPathArr = $BckFullPath.Split('\')
                                if($BckFullPathArr.Count -gt 0)
                                {
                                    $VMName=$BckFullPathArr[$BckFullPathArr.Count-2] # $VMName="VM01-System01"
                                    $SharedBckHDDLoc=$BckFullPathArr[$BckFullPathArr.Count-1]  #$SharedBckHDDLoc="SQLData.vhdx"
                                    
                                    $object = $ShareHDDLocBack | where {($_.VMName -eq $VMName) -and ($_.SharedHDDLoc -like '*'+$SharedBckHDDLoc)}
                                    $index = [array]::IndexOf($ShareHDDLocBack, $object)
                                    if ($index -ne -1)
                                    {
                                        $ShareHDDLocBack[$index].SharedBckHDDLoc=$BckFullPath
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        # !!! Put breakpoint here !!!
        # if you get any error try to manualy restore checkpoint
        # Restore checkpoint
        RestoreCheckPoint -SystemName $SystemName -CheckPointName $CheckPointName

        # !!! Put breakpoint here !!!
        # if you get any error try to manualy restore checkpoint
        if ($BackupLocation)
        {
            # refresh VMs with shared HDD
            ForEach ($VMSharedHDD in $VMSharedHDDs)
            {
                Write-Output "Refresh data for VM: $($VMSharedHDD.Name)"
                Write-Output "Refresh data for VM: $($VMSharedHDD.Name)" | Out-File -FilePath $outLogFileName -Append

                $result = Read-SCVirtualMachine -VM $VMSharedHDD
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

            # Copy shared VHD from backup location to VM HDD location
            # !!! Put breakpoint here !!!
            # if get any error during the copy of shared vhdx files to bacup location, copy these files manually
            ForEach ($SharedHDD in $ShareHDDLocBack)
            {
                if ($SharedHDD.SharedBckHDDLoc -ne "")
                {
                   $sourecFileName = $SharedHDD.SharedBckHDDLoc

                   $destinationFileName = $SharedHDD.SharedOrigHDDLoc

                   Write-Output "`nCopy: $($sourecFileName), size: [$($SharedHDD.SizeHDD)]GB to location: $($destinationFileName)"
                   Write-Output "`nCopy: $($sourecFileName), size: [$($SharedHDD.SizeHDD)]GB to location: $($destinationFileName)" | Out-File -FilePath $outLogFileName -Append

                   Start-BitsTransfer -Source $sourecFileName -Destination $destinationFileName `
                                      -Description "To Destination: [$destinationFileName]" `
                                      -DisplayName "Restore [$sourecFileName], Size:[$($SharedHDD.SizeHDD)]GB"

                   Write-Output "`nCopy completed: $($sourecFileName), to: $($destinationFileName)"
                   Write-Output "`nCopy completed: $($sourecFileName), to: $($destinationFileName)" | Out-File -FilePath $outLogFileName -Append
                }
            }
            #---------------------------------------------------------------------------------
            # After copied shared HDD from backup location to first HIST serve, add those HDDs to HIST VMs
            Write-Output 'After restore checkpoint add shared hdd back to VM(s)'
            Write-Output 'After restore checkpoint add shared hdd back to VM(s)' | Out-File -FilePath $outLogFileName -Append

            # !!! Put breakpoint here !!!
            # if you get any error when try to add shared hdd to VM, stop after this block of code {...} and add shared
            # hdds to VM manually based on information previously written on console for shared HDD location (property SharedHDDLoc)
            ForEach($ShareHDD in $ShareHDDLocBack)
            {
                Write-Output "Add shared HDD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]"
                Write-Output "Add shared HDD: [$($ShareHDD.SharedHDDLoc)] to VM: [$($ShareHDD.VMName)]" | Out-File -FilePath $outLogFileName -Append
                
                $result=Add-VMHardDiskDrive -VMName $ShareHDD.VMName -ControllerType SCSI -ControllerNumber $ShareHDD.ControllerNumber `
                        -ControllerLocation $ShareHDD.ControllerLocation -Path $ShareHDD.SharedHDDLoc -AllowUnverifiedPaths `
                        -ComputerName $ShareHDD.HostName -SupportPersistentReservations -ErrorAction SilentlyContinue

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

        # !!! Put breakpoint here !!!
        # if you get any error when try to add shared hdd to VM, stop after upper block of code {...} and add shared
        # hdds to VM manually based on information previously written on console for shared HDD location (property SharedHDDLoc)
        # refresh ALL VMs from system name
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

        Write-Output "`nFinish RestoreCheckPoint [$CheckPointName] ...`nEnd time [$datetime]`n"
        Write-Output "`nFinish RestoreCheckPoint [$CheckPointName] ...`nEnd time [$datetime]`n" | Out-File -FilePath $outLogFileName -Append

        New-TimeSpan –Start $StartDate –End $EndDate
   }
}
