# Load Common Code
Import-Module $PSScriptRoot\..\..\xSQLServerHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SQLInstanceName,

        [System.String]
        $SQLServer = $env:COMPUTERNAME
    )

    if(!$SQL)
    {
        $SQL = Connect-SQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
        $MinMemory = $sql.Configuration.MinServerMemory.ConfigValue
        $MaxMemory = $sql.Configuration.MaxServerMemory.ConfigValue
    }

    $returnValue = @{
        SQLInstanceName = $SQLInstanceName
        SQLServer = $SQLServer
        MinMemory = $MinMemory
        MaxMemory = $MaxMemory
    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SQLInstanceName,

        [System.String]
        $SQLServer = $env:COMPUTERNAME,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = 'Present',

        [System.Boolean]
        $DynamicAlloc = $false,

        [System.Int32]
        $MaxMemory = 2147483647,

        [System.Int32]
        $MinMemory = 0
    )

    if(!$SQL)
    {
        $SQL = Connect-SQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    If($SQL)
    {
        switch($Ensure)
        {
            "Absent"
            {
                $MaxMemory = 2147483647
                $MinMemory = 0
            }

            "Present"
            {
                if ($DynamicAlloc)
                {
                    $MaxMemory = Get-MaxMemoryDynamic $SQL.PhysicalMemory
                    $MinMemory = 128

                    New-VerboseMessage -Message "Dynamic Max Memory is $MaxMemory"
                }
            }
        }

        try
        {            
            $SQL.Configuration.MaxServerMemory.ConfigValue = $MaxMemory
            $SQL.Configuration.MinServerMemory.ConfigValue = $MinMemory
            $SQL.alter()

            New-VerboseMessage -Message "SQL Server Memory has been capped to $MaxMemory. MinMemory set to $MinMemory."
        }
        catch
        {
            New-VerboseMessage -Message "Failed setting Min and Max SQL Memory"
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SQLInstanceName,

        [System.String]
        $SQLServer = $env:COMPUTERNAME,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = 'Present',

        [System.Boolean]
        $DynamicAlloc = $false,

        [System.Int32]
        $MaxMemory = 0,

        [System.Int32]
        $MinMemory
    )

    if(!$SQL)
    {
        $SQL = Connect-SQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
        $GetMinMemory = $sql.Configuration.MinServerMemory.ConfigValue
        $GetMaxMemory = $sql.Configuration.MaxServerMemory.ConfigValue
    }

    switch($Ensure)
    {
        "Absent"
        {
            if ($GetMaxMemory -ne 2147483647)
            {
                New-VerboseMessage -Message "Current Max Memory is $GetMaxMemory. Expected 2147483647"
                return $false
            }

            if ($GetMinMemory -ne 0)
            {
                New-VerboseMessage -Message "Current Min Memory is $GetMinMemory. Expected 0"
                return $false
            }
        }

        "Present"
        {
            if ($DynamicAlloc)
            {
                $MaxMemory = Get-MaxMemoryDynamic $SQL.PhysicalMemory
                $MinMemory = 128

                New-VerboseMessage -Message "Dynamic Max Memory is $MaxMemory"
            }

            if($MaxMemory -ne $GetMaxMemory)
            {
                New-VerboseMessage -Message "Current Max Memory is $GetMaxMemory, expected $MaxMemory"
                return $false
            }

            if($PSBoundParameters.ContainsKey('MinMemory'))
            {
                if($MinMemory -ne $GetMinMemory)
                {
                    New-VerboseMessage -Message "Current Min Memory is $GetMinMemory, expected $MinMemory"
                    return $false
                }
            }
        }
    }

    $true
}


function Get-MaxMemoryDynamic
{
    param(
        $serverMem
    )

    if ($serverMem -ge 128000)
    {
        #Server mem - 10GB
        $MaxMemory = $serverMem - 10000 
    }
    elseif ($serverMem -ge 32000 -and $serverMem -lt 128000) 
    {
        #Server mem - 4GB 
        $MaxMemory = $serverMem - 4000
    }
    elseif ($serverMem -ge 16000)
    {
        #Server mem - 2GB 
        $MaxMemory = $serverMem - 2000
    }
    else
    {
        #Server mem - 1GB 
        $MaxMemory = $serverMem - 1000
    }

    $MaxMemory
}

Export-ModuleMember -Function *-TargetResource

