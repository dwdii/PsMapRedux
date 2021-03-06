<#
-------------------------------------------------------------------
An example of how to use the PsMapRedux PowerShell Module.
#>
cls

# Import our MapRedux module...
$Path = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
Import-Module -name ($Path + "\PsMapRedux")

# Import the SQL Server Module.
Import-Module “sqlps” -DisableNameChecking

Set-Location SQLSERVER:\sql\mydbserver\default\databases\MyDb
$query = "SELECT TOP 5000 Key1, Date, Value1 FROM MonitoringHourlyBiogas ORDER BY Key1";
Write-Host "Query: $query"
$dataset = Invoke-SqlCmd -query $query

# Define the Map function
$MyMap =
{ 
    Param
    (
        [PsObject] $dataset
    )
    
    Write-Host ($env:computername + "::Map");
    
    $list = @{};
    foreach($row in $dataset.Data)
    {
        if($list.ContainsKey($row.Key1) -eq $true)
        {
            $s = $list.Item($row.Key1);
            $s.Sum += $row.Value1;
            $s.Count++;
        }
        else
        {
            $s = New-Object PSObject;
            $s | Add-Member -Type NoteProperty -Name Key1 -Value $row.Key1;
            $s | Add-Member -type NoteProperty -Name Sum -Value $row.Value1;
            $s | Add-Member -type NoteProperty -Name Count -Value 1;
            $list.Add($row.Key1, $s);
        }
    }
    
    Write-Output $list;
}

# Define the Reduce Function
$MyReduce =
{ 
    Param
    (
        [object] $key,
        
        [PSObject] $dataset
    )
    
    Write-Host ($env:computername + "::Reduce - Count: " + $dataset.Data.Count)
    
    $redux = @{};
    foreach($s in $dataset.Data)
    {
        $sum += $s.Sum;
        $count += $s.Count;    
    }

    # Reduce
    $redux.Add($s.Key1, $sum / $count);

    # Return    
    Write-Output $redux;
}


# Create the item data
$Mr = New-MapReduxItem "My Example MapReduce Job" $MyMap $MyReduce 

$MyNodes = ("node1",  
            "node2",  
            "node3")

# Run the Map Reduce routine...
$MyMrResults = Invoke-MapRedux -MapReduceItem $Mr -ComputerName $MyNodes -DataSet $dataset -Verbose

# Show the results
Set-Location C:\
$MyMrResults | Out-GridView