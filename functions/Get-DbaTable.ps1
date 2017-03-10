﻿function Get-DbaTable
{
<#
<#
.SYNOPSIS
Returns a summary of information on the table
.DESCRIPTION
Shows table information around table row and data sizes and if it has any table type information. 
.PARAMETER SqlInstance
SQLServer name or SMO object representing the SQL Server to connect to. This can be a
collection and recieve pipeline input
.PARAMETER SqlCredential
PSCredential object to connect as. If not specified, currend Windows login will be used.
.PARAMETER Database
Define the database you wish to search
.PARAMETER IncludeSystemDBs
Switch parameter that when used will display system database information
.PARAMETER Table
Define a specific table you would like to query
.PARAMETER Silent 
Use this switch to disable any kind of verbose messages
	
.NOTES 
Original Author: Stephen Bennett, https://sqlnotesfromtheunderground.wordpress.com/
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.	
	
.LINK
https://dbatools.io/Get-DbaTable
.EXAMPLE
Get-DbaTable -SqlInstance DEV01 -Database Test1
Return all tables in the Test1 database
.EXAMPLE
Get-DbaTable -SqlInstance DEV01 -Database MyDB -Table MyTable
Return only information on the table MyTable from the database MyDB

#>
	[CmdletBinding()]
	param ([parameter(ValueFromPipeline, Mandatory = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[object[]]$SqlInstance,
		[System.Management.Automation.PSCredential]$SqlCredential,
		[switch]$IncludeSystemDBs,
		[switch]$Silent,
		[string[]]$Table
	)
	
	DynamicParam { if ($SqlInstance) { return Get-ParamSqlDatabases -SqlServer $SqlInstance[0] -SqlCredential $SourceSqlCredential } }
	
	BEGIN
	{
		$databases = $psboundparameters.Databases
		$exclude = $psboundparameters.Exclude
		
		$fqtns = @()
		
		if ($Table)
		{
			foreach ($t in $Table)
			{
				$dotcount = ([regex]::Matches($t, "\.")).count
				
				if ($dotcount -eq 1)
				{
					$schema = $t.Split(".")[0]
					$table = $t.Split(".")[1]
				}
				
				if ($dotcount -eq 2)
				{
					$database = $t.Split(".")[0]
					$schema = $t.Split(".")[1]
					$table = $t.Split(".")[2]
				}
				
				$fqtn = [PSCustomObject] @{
					Database = $database
					Schema = $Schema
					Table = $table
				}
				$fqtns += $fqtn
			}
		}
	}
	
	PROCESS
	{
		foreach ($instance in $sqlinstance)
		{
			#For each SQL Server in collection, connect and get SMO object
			Write-Message -Level Verbose -Message "Connecting to $instance"
			
			try
			{
				Write-Message -Level Verbose -Message "Connecting to $instance"
				$server = Connect-SqlServer -SqlServer $instance -SqlCredential $sqlcredential
			}
			catch
			{
				Stop-Function -Message "Failed to connect to: $instance" -Continue -Target $instance
			}
			
			#If IncludeSystemDBs is true, include systemdbs
			#only look at online databases (Status equal normal)
			try
			{
				if ($databases.length -gt 0)
				{
					$dbs = $server.Databases | Where-Object { $databases -contains $_.Name }
				}
				elseif ($IncludeSystemDBs)
				{
					$dbs = $server.Databases | Where-Object { $_.status -eq 'Normal' }
				}
				else
				{
					$dbs = $server.Databases | Where-Object { $_.status -eq 'Normal' -and $_.IsSystemObject -eq 0 }
				}
				
				if ($exclude.length -gt 0)
				{
					$dbs = $dbs | Where-Object { $exclude -notcontains $_.Name }
				}
			}
			catch
			{
				Stop-Function -Message "Unable to gather dbs for $instance" -Target $instance -Continue
			}
			
			foreach ($db in $dbs)
			{
				Write-Message -Level Verbose -Message "Processing $db"
				
				$d = $server.Databases[$db]
				if ($fqtns)
				{
					foreach ($fqtn in $fqtns)
					{
						if ($fqtn.schema)
						{
							try
							{
								$db.Tables | Where-Object { $_.name -eq $table -and $_.Schema -eq $schema } | Select-DefaultView -Property Parent, Schema, Name, IndexSpaceUsed, DataSpaceUsed, RowCount, HasClusteredIndex, IsFileTable, IsMemoryOptimized, IsPartitioned, FullTextIndex, ChangeTrackingEnabled
							}
							catch
							{
								Write-Message -Level Warning "Could not find table name: $($fqtn.table) schema: $($fqtn.schema)"
							}
						}
						else
						{
							try
							{
								$db.Tables | Where-Object { $_.name -eq $table } | Select-DefaultView -Property Parent, Schema, Name, IndexSpaceUsed, DataSpaceUsed, RowCount, HasClusteredIndex, IsFileTable, IsMemoryOptimized, IsPartitioned, FullTextIndex, ChangeTrackingEnabled
							}
							catch
							{
								Write-Message -Level Warning "Could not find table name: $($fqtn.table) schema: $($fqtn.schema)"
							}
						}
						
					}
				}
				else
				{
					$db.Tables | Select-DefaultView -Property Parent, Schema, Name, IndexSpaceUsed, DataSpaceUsed, RowCount, HasClusteredIndex, IsFileTable, IsMemoryOptimized, IsPartitioned, FullTextIndex, ChangeTrackingEnabled
				}
			}
		}
	}
}