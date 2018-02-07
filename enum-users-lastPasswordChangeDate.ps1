#
# Brett Gross
# enum-users-lastPasswordChangeDate.ps1
#

################
## Functions
################


Function retrieve-hosts-file {
	$file_path = Read-Host "What is the file path"
	if (Test-Path $file_path){
		$host_list = Get-Content $file_path
		if ($host_list.Length -eq 0){
			Write-Host "The file path provided does not contain any hosts!" -ForegroundColor Red		
		} else {

			# Remove any whitespace/null entries.
			$host_list = $host_list.split("", [System.StringSplitOptions]::RemoveEmptyEntries)			
			Write-Host "Successfully retrieved host list."
			return $host_list
		}	
	} else {
		Write-Host "File path was not provided or is invalid or couldn't be found. Please try again." -ForegroundColor Red
	}
}

Function retrieve-PasswordLastSet {
$dict = @{}
	foreach ($user in $host_list){
		if ($user){	$user = $user.Trim() }	
		try {
			$dict[$user] = get-aduser -identity $user -properties PasswordLastSet,pwdLastSet,Enabled,LogonCount | select PasswordLastSet,pwdLastSet,Enabled,LogonCount
		} catch {
			write-host "Error looking up AD info on $user"
		}
	}
	write-host "Count: $($dict.count)"
	return $dict
}

Function compare-PasswordLastSet-and-date ($host_dict) {	
	$counter = 0
	$compare_date = Read-Host "What is the date you want to compare (mm/dd/yyyy hh:mm:ss tt) "
	$show_not_changed = Read-Host "Show only users that have not changed since $compare_date? (Use - to show 'AtNextLogon') [Y/n/-]"

	if ($show_not_changed.toupper() -eq "Y"){	
		write-host "***************************************************"
		write-host "Users that HAVE NOT changed password since $compare_date"
		write-host "***************************************************"

		foreach ($user in $host_dict.Keys){
			if ($host_dict[$user].pwdLastSet.ToString() -eq "0"){
				#write-host "$user has a value of $($host_dict[$user].pwdLastSet)"
			} else {
				if ((get-date $host_dict[$user].PasswordLastSet.ToString()) -lt (get-date $compare_date)){
					write-host "$user, $($host_dict[$user].PasswordLastSet)"
					$counter++
				}
			}
		}
	} elseif ($show_not_changed.toupper() -eq "N") {
		write-host "***************************************************"
		write-host "Users that HAVE changed password since $compare_date"
		write-host "***************************************************"

		foreach ($user in $host_dict.Keys){
			if ($host_dict[$user].pwdLastSet.ToString() -eq "0"){
				#write-host "$user has a value of $($host_dict[$user].pwdLastSet)"
			} else {
				if ((get-date $host_dict[$user].PasswordLastSet.ToString()) -gt (get-date $compare_date)){
					write-host "$user, $($host_dict[$user].PasswordLastSet)"
					$counter++
				}
			}
		}
	} elseif ($show_not_changed -eq "-"){
		write-host "***************************************************"
		write-host "Users that haven't logged on since 'AtNextLogon' toggle"
		write-host "***************************************************"

		foreach ($user in $host_dict.Keys){
			# Excluding inactive user accounts.
			if ($host_dict[$user].Enabled){	
				if ($host_dict[$user].pwdLastSet.ToString() -eq "0"){
					write-host "$user has a value of $($host_dict[$user].pwdLastSet)"
					$counter++
				}
			}
		}
	}
	# Stats
	write-host "Counter: $counter"
}


Function press-any-key {
	Write-Host "Press any key to continue ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Function Show-Menu {

Param(
[Parameter(Position=0,Mandatory=$True,HelpMessage="Enter your menu text")]
[ValidateNotNullOrEmpty()]
[string]$Menu,
[Parameter(Position=1)]
[ValidateNotNullOrEmpty()]
[string]$Title="Menu",
[switch]$ClearScreen
)

# Disable clearing screen for history.
#if ($ClearScreen) {Clear-Host}

#build the menu prompt
$menuPrompt=$title
#add a return
$menuprompt+="`n"
#add an underline
$menuprompt+="-"*$title.Length
$menuprompt+="`n"
#add the menu
$menuPrompt+=$menu

Read-Host -Prompt $menuprompt

} #end function

################
## Variables
################

$menu = @"
1. Ingest host list from file path
2. Pull in PasswordLastSet
3. Compare custom date with PasswordLastSet
4. Print User Dictionary
Q. To Quit the script

Select a task by number or Q to quit
"@

$host_dict = @{}
$host_list = ""
$log_file = (get-location).path + "\tripwire_helper.log"

################
## Main loop
################

Do {

	#use a Switch construct to take action depending on what menu choice is selected.
	Switch (Show-Menu $menu "My Script Helper Tasks" -clear) {
	"1" {
		Write-Host "** Ingest user list from file path **" -ForegroundColor Green
		$host_list = retrieve-hosts-file
		#foreach ($h in $host_list){	Write-Host $h }	
		write-host "Count: $($host_list.length)"	
		press-any-key
	}
	
	"2" {
		Write-Host "** Pull PasswordLastSet Value for all users **" -ForegroundColor Green
		if (![string]::IsNullOrEmpty($host_list)){
			$host_dict = retrieve-PasswordLastSet
		}
		press-any-key
	}

	"3" {
		if (![string]::IsNullOrEmpty($host_dict)){
			compare-PasswordLastSet-and-date $host_dict
		} else {
			Write-Host "** Host dictionary does not exist **" -ForegroundColor Red
		}
		press-any-key
	}

	"4" {
		if (![string]::IsNullOrEmpty($host_dict)){
			Write-Host "** Printing host dictionary **" -ForegroundColor Green
			#$host_dict.GetEnumerator() | % {Write-Host $($_.key) $($_.value)}
			$counter = 0
			foreach ($user in $host_dict.Keys){	

				# Excluding inactive user accounts.
				if ($host_dict[$user].Enabled){	
					Write-Host "$user $($host_dict[$user])"
					$counter++				
				}
			}
			Write-Host "Counter: $counter"

		} else {
			Write-Host "** Host dictionary does not exist **" -ForegroundColor Red
		}
		press-any-key
	}
		"Q" {Write-Host "** Goodbye **" -ForegroundColor Cyan
		Return
	}	
	Default {Write-Warning "Invalid Choice. Try again."  -ForegroundColor Red
			sleep -milliseconds 750}
	} #switch	
} While ($True)
