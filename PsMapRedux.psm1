# 
# Date: March 27 2012 
# Daniel Dittenhafer
# MapReduce framework module for PowerShell

function New-MapReduxItem
{
    Param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string] $Name,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=1, Mandatory=$true)]
        [ScriptBlock] $MapFunction,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=2, Mandatory=$true)]
        [ScriptBlock] $ReduceFunction
    )
    
    process
    {
        $Obj = New-Object PSObject;
        
        $Obj | Add-Member -Type NoteProperty -Name Name -Value $Name;
        $Obj | Add-Member -type NoteProperty -Name Map -Value $MapFunction;
        $Obj | Add-Member -type NoteProperty -Name Reduce -Value $ReduceFunction;
        
        $Obj;
    }
    
    <#
        .SYNOPSIS
        Creates a new instance the "MapReduxItem" structure used by the Invoke-MapRedux function.
        
        .Description
        
        
        .PARAMETER MapFunction
        The script block that performs the mapping with a subset of the dataset. This scriptblock should take the form shown in the example.
        
        .PARAMETER ReduceFunction
        The script block that performs the reducer activities with the results of the map function.
        
        .EXAMPLE
        
        $aMap = {
            Param
            (
                [PsObject] $dataset
            )
            
            # Indicate the job is running on the remote node.
            Write-Host ($env:computername + "::Map");
            
            # The hashtable to return
            $list = @{};
            
            # ... Perform the mapping work and prepare the $list hashtable result with your custom PSObject...
            # ... The $dataset has a single 'Data' property which contains an array of data rows 
            #     which is a subset of the originally submitted data set.
    
            # Return the hashtable (Key, PSObject)
            Write-Output $list;
        }
        
        # A Reduce scriptblock
        $aReduce =
        { 
            Param
            (
                [object] $key,
                
                [PSObject] $dataset
            )
            
            Write-Host ($env:computername + "::Reduce - Count: " + $dataset.Data.Count)
            
            # The hashtable to return
            $redux = @{};
            
            # Return    
            Write-Output $redux;
        }
        
        # Create the item data
        $Mr = New-MapReduxItem "My Example MapRedux Job" $MyMap $MyReduce 
        
        .LINK
        http://geekswithblogs.net/dwdii
        
        .NOTES
        Name:   New-MapReduxItem
        Author: Daniel Dittenhafer
    #>      
}

function New-MapReduxJob
{
    Param
    (
        [ValidateNotNullOrEmpty()]
        [string] $NodeName,
        
        [ValidateNotNullOrEmpty()]
        [object] $DataSet
    )
    
    process
    {
        $Obj = New-Object PSObject;
        
        $Obj | Add-Member -Type NoteProperty -Name NodeName -Value $NodeName;
        $Obj | Add-Member -type NoteProperty -Name DataSet -Value $DataSet;
        $Obj | Add-Member -type NoteProperty -Name Job -Value $null;
        
        $Obj;        
    }
}

function New-NodeState
{
    Param
    (
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        
        [ValidateNotNullOrEmpty()]
        [bool] $Enabled,
 
        [ValidateNotNullOrEmpty()]
        [bool] $Active
    )
    
    process
    {
        $Obj = New-Object PSObject;
        
        $Obj | Add-Member -Type NoteProperty -Name Name -Value $Name;
        $Obj | Add-Member -type NoteProperty -Name Enabled -Value $Enabled;
        $Obj | Add-Member -type ScriptProperty -Name Active -Value { ActiveJobs -gt 0}
        $Obj | Add-Member -type NoteProperty -Name MaxJobs -Value 5
        $Obj | Add-Member -type NoteProperty -Name ActiveJobs -Value 0
        $Obj | Add-Member -type NoteProperty -Name TotalJobsProcessed -Value 0

        $Obj;        
    }
}

function Initialize-MapReduxNode
{
    Param
    (
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName
    )
    
    process
    {
        #Local Variables
        $nodes = @{};
        
        # Map - Loop for each node...
        foreach($cn in $ComputerName)
        {
            # track the node.
            $nodes.Add($cn, (New-NodeState -Name $cn -Enabled $true -Active $false))
        }
        
        # Return
        $nodes;
    }
}

function Get-MapChunk
{
    Param
    (
        [ValidateNotNullOrEmpty()]
        [object[]] $DataSet,
        [int] $SubsetCount,
        [int] $CurPart
    )

    process
    {
        $start = $CurPart * $SubsetCount
        $max = $start + $SubsetCount;
        
        ConvertTo-MapReduxDataSet -DataSet $DataSet[$start..($max - 1)] | Write-Output 
    }    
}

function ConvertTo-MapReduxDataSet
{
    Param
    (
        [object] $DataSet
    )
    
    process
    {
        $Obj = New-Object PSObject;
        $Obj | Add-Member -Type NoteProperty -Name Data -Value $DataSet;
        $Obj;      
    }
}

function New-MapReduxInvocation
{
    Param
    (
        [hashtable] $Nodes
    )
    
    process
    {
        $Obj = New-Object PSObject;
        
        $Obj | Add-Member -type NoteProperty -Name Nodes -Value $Nodes;
        $Obj | Add-Member -Type NoteProperty -Name Maps -Value @{};
        $Obj | Add-Member -Type NoteProperty -Name PsJobs -Value @{};
        $Obj | Add-Member -Type NoteProperty -Name Reducers -Value @{};
        $Obj | Add-Member -type NoteProperty -Name Partitions -Value @{};
        $Obj | Add-Member -type NoteProperty -Name FinalResults -Value @();
        
        $Obj;          
    }
}

function Start-MapReduxMapper
{
    Param
    (
        [PSObject] $Mri,
        [object[]] $DataSet
    )
    
    process
    {
        $CurPart = 0;
        $NodeJobsMax = $Mri.Nodes.Count * $Mri.Nodes[0].MaxJobs;
        $SubsetCount = $DataSet.Count / ($Mri.Nodes.Count);

        # Map - Loop for each node...
        foreach($n in $mri.Nodes.Values)
        {
            # Split into a 'managable' junk for the mapper
            $subset = Get-MapChunk -DataSet $DataSet -SubsetCount $SubsetCount -CurPart $CurPart

            # Run job on a node
            $mj = Submit-MapReduxJob -Nodes $nodes -MapReduceFx $MapReduceItem.Map -DataSet $subset
            
            # Add to our job list
            $mri.PsJobs.Add($mj.Job.Id, $mj.Job);
            $mri.Maps.Add($mj.Job.Id, $mj);
            $CurPart++;
        }

        # Return
        Write-Output $Mri;
    }    
}

function Complete-MapperStep
{
    Param
    (
        [PSObject] $Job,
        [hashtable] $MapResults,
        [PSObject] $Mri
    )

    process
    {                
        # Partition
        foreach($key in $mapResults.Keys)
        {
            if($Mri.Partitions.ContainsKey($key))
            {
                $Mri.Partitions.Item($key) += $mapResults.Item($key);
            }
            else
            {
                $Mri.Partitions.Add($key, @($mapResults.Item($key)));
            }
        }

        # Update Maps list.                
        $Mri.Maps.Remove($Job.Id);
        
        # Return
        Write-Output $Mri;
    }
    
}

function Complete-ReducerStep
{
    Param
    (
        [PSObject] $Job,
        [hashtable] $ReducerResults,
        [PSObject] $Mri
    )
    
    process
    {
        # Get the map results 
        $Mri.FinalResults += $ReducerResults
            
        # Update Reducers list.                
        $Mri.Reducers.Remove($Job.Id);
        
        # Return
        Write-Output $Mri
    }
}

function Complete-MapReduxStep
{
    Param
    (
        [PSObject] $Mri,
        
        [PSObject] $MapReduceFx,
        
        [ScriptBlock] $CompletionFx,
        
        [switch] $ReceiveFailureResults
    )
    
    process
    {
        $bCompletedOrFailed = $true;
    
        # Wait for at least one job to finish, and then we can start partitioning...
        do
        {
            $jobsarray = @(1..($Mri.PsJobs.Count))
            $Mri.PsJobs.Values.CopyTo($jobsarray, 0);
            Wait-Job -Job $jobsarray -Any | Out-Null
            do
            {
                # Switch back and forth...
                if($bCompletedOrFailed)
                {
                    $state = "Completed";
                }
                else
                {
                    $state = "Failed";
                }
            
                # Get a job with the given state...
                $job = $jobsarray | Where-Object {$_.State -eq $state} | Select-Object -First 1
                $bCompletedOrFailed = -not $bCompletedOrFailed;
            }
            while(($job -eq $null) -and ($jobsarray.Count -gt 0))
            
            # Are we done?
            if($job -eq $null)
            {
                # NO OP
            }
            else
            {
                if($job.State -eq "Completed")
                {
                    # Call the completion routine...
                    #
                    # Get the map results 
                    Write-Verbose ("Receiving results from " + $job.Location + "...");
                    $results = Receive-Job -Job $job

                    # Call the completion routine itself
                    $Mri = Invoke-Command -ScriptBlock $CompletionFx -ArgumentList ($Job, $results, $Mri)
                    
                    # Finish...
                    Remove-Job -Job $job
                    $Mri.PsJobs.Remove($job.Id)
                    $node = $Mri.Nodes.Item($job.Location);
                    $node.ActiveJobs--;
                    $node.Enabled = $true;
                    $node.TotalJobsProcessed++;
                }
                else 
                {
                    if($job.State -eq "Failed")
                    {
                        # Get the cooresponding mapjob                    
                        $mj = $Mri.Maps.Item($job.Id)
                        if($mj -eq $null)
                        {
                            $mj = $Mri.Reducers.Item($job.Id);
                            $bReducer = $true;
                        }
    
                        # If node is still enabled, then report to screen...                    
                        $node = $Mri.Nodes.Item($mj.NodeName);
                        if($node.Enabled -eq $true)
                        {
                            # Warning....
                            Write-Warning ("Node failed (" + $node.Name + ") - Marked as disabled and resubmitting job");
                            if($ReceiveFailureResults.IsPresent)
                            {                        
                                # See what comes back...
                                $results = Receive-Job -Job $job
                            }
                        }
                        
                        # Need to mark the map node as 'down' and resubmit this job to another node...
                        $node.Enabled = $false;
                        $node.ActiveJobs--;
                        
                        # Resubmit the Map job...
                        $mj = Submit-MapReduxJob -Nodes $Mri.Nodes -MapReduceFx $MapReduceFx -DataSet $mj.DataSet
                        if($mj -eq $null)
                        {
                            Write-Verbose ("All nodes busy, waiting briefly to resubmit...");
                            Start-Sleep -Milliseconds 100
                        }
                        else
                        {
                            # Cleanup
                            Remove-Job -Job $job
                            $Mri.PsJobs.Remove($job.Id)
                            
                            if($bReducer)
                            {
                                $Mri.Reducers.Remove($job.Id)
                                $Mri.Reducers.Add($mj.Job.Id, $mj);
                            }
                            else
                            {
                                $Mri.Maps.Remove($job.Id)
                                $Mri.Maps.Add($mj.Job.Id, $mj);
                            }
                            
                            $Mri.PsJobs.Add($mj.Job.Id, $mj.Job)
                            
                        }
                    }
                }
            }
        }
        while($mri.PsJobs.Count -gt 0)
        
        # Return
        Write-Output $Mri
    }
}

function Start-MapReduxReducer
{
    Param
    (
        [PSObject] $Mri,
        
        [object[]] $Keys
        
    )
    
    process
    {
        # Now we can start the Reducer jobs...
        foreach($key in $Keys)
        {
            # Run job on a node
            $reducerData = ConvertTo-MapReduxDataSet -DataSet ($mri.Partitions.Item($key))
            $mj = Submit-MapReduxJob -Nodes $mri.Nodes -MapReduceFx $MapReduceItem.Reduce -DataSet ($key, $reducerData) #-AsLocal
            
            # Add to our job list
            if($mj.Job -eq $null)
            {
                # No Job Created!
                $failedToStart += $key;
                Write-Warning "Reducer job failed to initiate for key $key!"
            }
            else
            {
                $mri.PsJobs.Add($mj.Job.Id, $mj.Job);
                $mri.Reducers.Add($mj.Job.Id, $mj);
            }
        }
        
        # Return
        Write-Output $failedToStart;    
    }
}

function Invoke-MapRedux
{
    [CmdletBinding()]   
    Param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=0, Mandatory=$true)]  
        [PSObject] $MapReduceItem,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=1, Mandatory=$true)]  
        [string[]] $ComputerName,
        
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=2, Mandatory=$true)] 
        [object[]] $DataSet
    )

    process
    {
        $nodes = Initialize-MapReduxNode -ComputerName $ComputerName
        $mri = New-MapReduxInvocation -Nodes $nodes
        $finalresults = @(); 
        $retry = $mri.Partitions.Keys;
        $newRetry = @();
        
        # Start mapping...
        $mri = Start-MapReduxMapper -Mri $mri -DataSet $DataSet
        
        # Wait for mapper to finish, and perform partioning
        $mri = Complete-MapReduxStep -Mri $mri -MapReduceFx $MapReduceItem.Map -CompletionFx ${function:Complete-MapperStep} -ReceiveFailureResults
        
        do 
        {
            # Run the Reducer jobs...
            $newRetry = @();
            $newRetry = Start-MapReduxReducer -Mri $mri -Keys $retry
            
            $retry = @();
            $retry = $newRetry;
        }
        while($retry.Count -gt 0)
        
        # Read the results of the reducers...
        $mri = Complete-MapReduxStep -Mri $mri -MapReduceFx $MapReduceItem.Reduce -CompletionFx ${function:Complete-ReducerStep}
        #$finalresults += Invoke-Command -ScriptBlock $MapReduceItem.Reduce -ArgumentList ($key, $mri.Partitions.Item($key))
        
        # Save the invocation data so the caller can refer to it... 
        $global:MapReduxInvocation = $mri;
        
        # Return the final results to the caller...
        Write-Output $mri.FinalResults;
    }
    
    <#
        .SYNOPSIS
        Initiates a MapRedux distributed computation to the specified nodes using the specified MapReduxItem (Map and Reduce functions) and dataset. 
        
        .Description
        Requires WinRM to be enabled on the remote computers (i.e. winrm quickconfig).
        
        .PARAMETER MapReduceItem
        The object created by New-MapReduxItem containing a name for the invocation and the Map and Reduce scriptblocks.
        
        .PARAMETER ComputerName
        An array of one or more computers whichi will act as nodes for this distributed computation.
        
        .PARAMETER DataSet
        An array of objects which are the starting data set for this distributed computation. This can be an array of DataRows returned 
        from the SQL Server PowerShell Provider's Invoke-QueryCmd function, or a any custom array of data.
        
        .EXAMPLE
        
            # Import the SQL Server Module.
            Import-Module “sqlps” -DisableNameChecking

            # Query for the starting dataset
            Set-Location SQLSERVER:\sql\dbserver1\default\databases\myDb
            $query = "SELECT Key, Date, Value1 FROM BigData ORDER BY Key";
            Write-Host "Query: $query"
            $dataset = Invoke-SqlCmd -query $query        
            
            # Wrap the Map and Reduce scriptblocks
            $Mr = New-MapReduxItem "My Test MapReduce Job" $MyMap $MyReduce 
        
            # The remote nodes for processing
            $MyNodes = ("node1",  
                        "node2",  
                        "node3", 
                        "node4")

            # Run the Map Reduce routine...
            Measure-Command { $MyMrResults = Invoke-MapRedux -MapReduceItem $Mr -ComputerName $MyNodes -DataSet $dataset -Verbose}        
            
            # Show the results
            $MyMrResults | Out-GridView            
        
        .LINK
        http://geekswithblogs.net/dwdii
        
        .NOTES
        Name:   Invoke-MapRedux
        Author: Daniel Dittenhafer
    #>         
}

function Submit-MapReduxJob
{
    Param
    (
        [ScriptBlock] $MapReduceFx,
        [object] $DataSet,
        [hashtable] $Nodes,
        [switch] $AsLocal
    )
    
    process
    {
        # Local Variables
        $mj = $null;
        $theNode = $null;
    
        # We pick an enabled node?
        if($Nodes -ne $null)
        {
            foreach($n in $Nodes.Values)
            {
                if($n.Enabled -eq $true -and $n.ActiveJobs -lt $n.MaxJobs)
                {
                    $theNode = $n;
                    $n.ActiveJobs++;
                    break;
                }
            }
        }
        
        # Node specified?
        if($theNode -eq $null)
        {
            Write-Warning ("No nodes available for job!")
        }
        else
        {
            # Run job on a node
            $mj = New-MapReduxJob -NodeName $theNode.Name -DataSet $DataSet
            if($AsLocal.IsPresent)
            {
                $results = Invoke-Command -ScriptBlock $MapReduceFx -ArgumentList ($mj.DataSet)
            }
            else
            {
                $mj.Job = Invoke-Command -ComputerName $mj.NodeName -AsJob -JobName ($MapReduceItem.Name) -ScriptBlock $MapReduceFx -ArgumentList $mj.DataSet
            }
            
            # Verbose...
            Write-Verbose ($mj.NodeName + ": Job submitted"); # + $mj.DataSet.Data.length.ToString() + " rows submitted");
        }
        
        # Return 
        Write-Output $mj
    }
}
