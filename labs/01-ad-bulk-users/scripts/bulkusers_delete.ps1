# Import active directory module for running AD cmdlets
Import-Module ActiveDirectory -ErrorAction Stop

# Store the data from ADUsers.csv into the $ADUsers variable
$CSVPath = Join-Path $PSScriptRoot "..\data\bulkusers.template.csv"
$ADUsers = Import-Csv -Path $CSVPath -ErrorAction Stop

# Initialize counters
$DeletedUsers = 0
$NonExistingUsers = 0

# Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers) {
    $Username = $User.username
    $U = Get-ADUser -LDAPFilter "(sAMAccountName=$Username)" -ErrorAction SilentlyContinue
    # Check to see if the user is already deleted in AD
    if (-not $U) {
        # If user does exist, give a warning
        Write-Warning "A user account with username $Username is already deleted in Active Directory."
        $NonExistingUsers++
    } else {
        # User exists then proceed to delete the user account
        try {
             # Delete the user accounts
             Remove-ADUser -Identity $Username -Confirm:$false
             
             Write-Host "Deleted user: $Username" -ForegroundColor Green
             $DeletedUsers++
        } catch {
            Write-Error "Failed to delete user $Username. Error: $_"
        }
    }
}

# Display summary
Write-Host "`nBulk user delete completed:" -ForegroundColor Cyan
Write-Host "Users deleted: $DeletedUsers" -ForegroundColor Green

Write-Host "Non-Existing users skipped: $NonExistingUsers" -ForegroundColor Yellow
