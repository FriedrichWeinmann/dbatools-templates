﻿Function Verb-DbaNoun
{
<#
.SYNOPSIS
This is a simple template that shows a Set for a Windows-based best practice
	
.DESCRIPTION
This is a simple template that shows a Set for a Windows-based best practice
	
If your organization uses a custom power plan that is considered best practice, specify -PowerPlan
	
References:
https://support.microsoft.com/en-us/kb/2207548
http://www.sqlskills.com/blogs/glenn/windows-power-plan-effects-on-newer-intel-processors/
	
.PARAMETER ComputerName
The SQL Server (or server in general) that you're connecting to. The -SqlServer parameter also works. This command handles named instances.

.PARAMETER Detailed
Show a detailed list.
	
.PARAMETER PowerPlan
The Power Plan that you wish to use. These are validated to Windows default Nouns (Power saver, Balanced, High Performance)
	
.PARAMETER CustomPowerPlan
If you use a custom power plan instead of Windows default, use CustomPowerPlan

.NOTES 
Original Author: You (@YourTwitter, Yourblog.net)

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbatools.io/Verb-DbaNoun

.EXAMPLE
Verb-DbaNoun -ComputerName sqlserver2014a

To return true or false for Power Plan being set to High Performance
	
.EXAMPLE   
Verb-DbaNoun -ComputerName sqlserver2014a -Detailed
	
To return detailed information Nouns
	
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance", "SqlServer")]
		[string[]]$ComputerName,
		[ValidateSet('High Performance', 'Balanced', 'Power saver')]
		[string]$PowerPlan = 'High Performance',
		[string]$CustomPowerPlan
	)
	
	BEGIN
	{
		if ($CustomPowerPlan.Length -gt 0) { $PowerPlan = $CustomPowerPlan }
		
		Function Verb-DbaNoun
		{
			try
			{
				Write-Verbose "Testing connection to $server and resolving IP address"
				$ipaddr = (Test-Connection $server -Count 1 -ErrorAction SilentlyContinue).Ipv4Address | Select-Object -First 1
				
			}
			catch
			{
				Write-Warning "Can't connect to $server"
				return
			}
			
			try
			{
				Write-Verbose "Getting Power Plan information from $server"
				$query = "Select ElementName from Win32_PowerPlan WHERE IsActive = 'true'"
				$currentplan = Get-WmiObject -Namespace Root\CIMV2\Power -ComputerName $ipaddr -Query $query -ErrorAction SilentlyContinue
				$currentplan = $currentplan.ElementName
			}
			catch
			{
				Write-Warning "Can't connect to WMI on $server"
				return
			}
			
			if ($currentplan -eq $null)
			{
				# the try/catch above isn't working, so make it silent and handle it here.
				Write-Warning "Cannot get Power Plan for $server"
				return
			}
			
			$planinfo = [PSCustomObject]@{
				Server = $server
				PreviousPowerPlan = $currentplan
				ActivePowerPlan = $PowerPlan
			}
			
			If ($Pscmdlet.ShouldProcess($server, "Setting Power Plan to $PowerPlan"))
			{
				try
				{
					Write-Verbose "Setting Power Plan to $PowerPlan"
					$null = (Get-WmiObject -Name root\cimv2\power -ComputerName $ipaddr -Class Win32_PowerPlan -Filter "ElementName='$PowerPlan'").Activate()
				}
				catch
				{
					Write-Exception $_
					Write-Warning "Couldn't set Power Plan on $server"
					return
				}
				
				return $planinfo
			}
		}
	}
	
	PROCESS
	{
		foreach ($server in $ComputerName)
		{
			# Convert SQL instance name to Windows
			if ($server -match '\\')
			{
				$server = $server.Split('\\')[0]
			}
			
			if ($server -notin $processed)
			{
				$null = $processed.Add($server)
				Write-Verbose "Connecting to $server"
			}
			else
			{
				continue
			}
			
			$data = Verb-DbaNoun $server
			
			if ($data.Count -gt 1)
			{
				$data.GetEnumerator() | ForEach-Object { $_ }
			}
			else
			{
				$data
			}
		}
	}
}