Function DeleteCheckPoint
{
    <#
        .SYNOPSIS
            Delete Named Check point from all VMs contain system name.

        .DESCRIPTION
            Delete Named Check point from all VMs contain system name.

            All VMs must have the same checkpoint name.

            To Test from PowerShell IDE use following command:
            Import-Module -Name ".\DeleteCheckPoint.ps1" -Force

            DeleteCheckPoint -SystemName "-TrainingSystem01" -CheckPointName "20191217"

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
            Delete check point name "20191217" for VMs inside system name "-TrainingSystem01"

			DeleteCheckPoint -SystemName "-TrainingSystem01" -CheckPointName "20191217"

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
            Version 2.3 - 2020-10-07
                          Added output log messages to file inside .\Log folder 
    #>
    [CmdletBinding()]  
    param
    (
        [parameter(ParameterSetName="SystemName",Position=0,Mandatory=$true,HelpMessage="You must enter System Name")]
        [string]$SystemName="",

        [parameter(ParameterSetName="SystemName",Position=1,Mandatory=$true,HelpMessage="You must enter check point name")]
        [string]$CheckPointName=""
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

        Write-Output "`nStart time [$datetime]`nStarting DeleteCheckPoint ..."
        Write-Output "`nStart time [$datetime]`nStarting DeleteCheckPoint ..." | Out-File -FilePath $outLogFileName -Append
    }
    PROCESS
    {

        if (-not (Get-Module -Name Hyper-V | Where {$_.Version -eq 1.1}) )
        {
            Remove-Module Hyper-V -ErrorAction SilentlyContinue
        } 
        Import-Module Hyper-V -RequiredVersion 1.1

        $VMs=Get-SCVirtualMachine | Where {$_.Name -like "*$SystemName"} | Sort-Object -Property Name
        $VMNum=$VMs.Count
        Write-Output "VM(s) number: $VMNum"
        Write-Output "VM(s) number: $VMNum" | Out-File -FilePath $outLogFileName -Append
		foreach ($VM in $VMs)
		{
            if ($CheckPointName -ne "")
            {
                try 
                { 
                    $VMData=Get-SCVirtualMachine -Name $VM.Name -VMHost $VM.HostName
                    if($VMData)
                    {
                        Write-Output "`nStart deleting a checkpoint name: $CheckPointName, from VM: $($VM.Name), on host: $($VM.HostName)"
                        Write-Output "`nStart deleting a checkpoint name: $CheckPointName, from VM: $($VM.Name), on host: $($VM.HostName)" | Out-File -FilePath $outLogFileName -Append

                        $SnapshotName=Get-SCVMCheckpoint -VM $VMData | Where-Object { $_.Name -Eq $CheckPointName }
                        if($SnapshotName)
                        {
                            $result=$null
                            $result=Remove-SCVMCheckpoint -VMCheckpoint $SnapshotName -ErrorAction SilentlyContinue 
                            if(-not $?)
                            {
                                Write-Warning "`n"
                                Write-Warning "Error to remove check point name: $CheckPointName, does not exist on VM: $($VM.Name), on host: $($VM.HostName)"
                                Write-Warning "`n"
                                Write-Warning "`n" | Out-File -FilePath $outLogFileName -Append
                                Write-Warning "Error to remove check point name: $CheckPointName, does not exist on VM: $($VM.Name), on host: $($VM.HostName)" | Out-File -FilePath $outLogFileName -Append
                                Write-Warning "`n" | Out-File -FilePath $outLogFileName -Append
                            }
                            else
                            {
                                Write-Output "successfully removed checkpoint name: $CheckPointName, from VM: $($VM.Name), on host: $($VM.HostName)"
                                Write-Output "successfully removed checkpoint name: $CheckPointName, from VM: $($VM.Name), on host: $($VM.HostName)" | Out-File -FilePath $outLogFileName -Append
                            }
                        }
                        else
                        {
                            Write-Warning "`nCheckpoint name: $CheckPointName, does not exist on VM: $($VM.Name), on host: $($VM.HostName)"
                            Write-Warning "`nCheckpoint name: $CheckPointName, does not exist on VM: $($VM.Name), on host: $($VM.HostName)" | Out-File -FilePath $outLogFileName -Append
                        }
                    }
                    else
                    {
                        Write-Warning "`nVM: $($VM.Name), on host: $($VM.HostName), does not exist !!!"
                        Write-Warning "`nVM: $($VM.Name), on host: $($VM.HostName), does not exist !!!" | Out-File -FilePath $outLogFileName -Append
                    }
                }
                catch 
                { 
                    Write-Error "`n"
                    Write-Error "!!! Check if there is any child checkpoints !!!"
                    Write-Error "`n"
                    Write-Error "Get-VM $VM.Name -ComputerName $VM.HostName | Get-VMSnapshot -Name $CheckPointName | Remove-VMSnapshot"
                    Write-Error "`n"
                    Write-Error "Error message:"
                    Write-Error "======================================="
		            for($i=0; $i -le $error.Count-1; $i++)
		            {
                        Write-Error $error[$i]
                        Write-Error "----------------------------------------------------------------------------------"
                    }
                    Write-Error "`n"

                    Write-Error "`n" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "!!! Check if there is any child checkpoints !!!" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "`n" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "Get-VM $VM.Name -ComputerName $VM.HostName | Get-VMSnapshot -Name $CheckPointName | Remove-VMSnapshot" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "`n" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "Error message:" | Out-File -FilePath $outLogFileName -Append
                    Write-Error "=======================================" | Out-File -FilePath $outLogFileName -Append
		            for($i=0; $i -le $error.Count-1; $i++)
		            {
                        Write-Error $error[$i] | Out-File -FilePath $outLogFileName -Append
                        Write-Error "----------------------------------------------------------------------------------" | Out-File -FilePath $outLogFileName -Append
                    }
                    Write-Error "`n" | Out-File -FilePath $outLogFileName -Append

                    break
                }
            }

		}

        # refresh ALL VMs from system name
        $RefreshError=$false
        ForEach ($VM in $VMs)
        {
            Write-Output "Refresh data for VM: $($VM.Name)"
            Write-Output "Refresh data for VM: $($VM.Name)" | Out-File -FilePath $outLogFileName -Append

            $result = Read-SCVirtualMachine -VM $VM
            if ($result.MostRecentTaskUIState -ne 'Completed') # mora biti zadnji refresh u statusu 'Completed'
            {
                Write-Warning "Error to refresh VM: [$($VM.Name)]" 
                Write-Warning "Error to refresh VM: [$($VM.Name)]"  | Out-File -FilePath $outLogFileName -Append
    
                $RefreshError=$true
            }
        }

        if ($RefreshError)
        {
            Write-Warning 'Try to manually to refresh all VM(s).' 
            Write-Warning 'After that check if VM(s) work correctly and manually delete data from BackupLocation if exist' 
            Write-Warning 'Try to manually to refresh all VM(s).'  | Out-File -FilePath $outLogFileName -Append
            Write-Warning 'After that check if VM(s) work correctly and manually delete data from BackupLocation if exist'  | Out-File -FilePath $outLogFileName -Append
        }
        else
        {
            Write-Output 'Check if VM(s) work correctly and manually delete data from BackupLocation if exist' 
            Write-Output 'Check if VM(s) work correctly and manually delete data from BackupLocation if exist' | Out-File -FilePath $outLogFileName -Append
        }

        Remove-Module Hyper-V
        Import-Module Hyper-V
   }
    END
    {
        $date = Get-Date -Format yyyy-MM-dd
        $time = get-date -Format HH:mm:ss
        $datetime = $date + "|" + $time
        $EndDate=Get-Date

        Write-Output "`nFinish DeleteCheckPoint [$CheckPointName] ...`nEnd time [$datetime]`n"
        Write-Output "`nFinish DeleteCheckPoint [$CheckPointName] ...`nEnd time [$datetime]`n" | Out-File -FilePath $outLogFileName -Append

        New-TimeSpan –Start $StartDate –End $EndDate
    }
}






