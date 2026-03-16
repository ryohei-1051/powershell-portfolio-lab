# Import active directory module for running AD cmdlets
Import-Module ActiveDirectory -ErrorAction Stop

# Store the data from ADUsers.csv into the $ADUsers variable
$CSVPath = Join-Path $PSScriptRoot "..\data\bulkusers.template.csv"
$ADUsers = Import-Csv -Path $CSVPath -ErrorAction Stop

# Initialize counters
$CreatedUsers = 0
$ExistingUsers = 0

# Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers) {
    # Read user data from each field in each row and assign the data to a variable
    $Username = $User.username
    $Password = $User.password
    $Firstname = $User.firstname
    $Lastname = $User.lastname
    $OU = $User.ou
    $Email = $User.email
    $StreetAddress = $User.streetaddress
    $City = $User.city
    $State = $User.state
    $Country = $User.country
    $Telephone = $User.telephone
    $JobTitle = $User.jobtitle
    $Company = $User.company
    $Department = $User.department

    # Check to see if the user already exists in AD
    if (Get-ADUser -Filter { SamAccountName -eq $Username }) {
        # If user does exist, give a warning
        Write-Warning "A user account with username $Username already exists in Active Directory."
        $ExistingUsers++
    } else {
        # User does not exist then proceed to create the new user account
        try {
            # Create the new user account
            # Note: Replace "example.local" with your actual domain
            New-ADUser `
                -SamAccountName $Username `
                -UserPrincipalName "$Username@example.local" `
                -Name "$Firstname $Lastname" `
                -GivenName $Firstname `
                -Surname $Lastname `
                -Enabled $True `
                -DisplayName "$Lastname, $Firstname" `
                -Path $OU `
                -City $City `
                -Company $Company `
                -State $State `
                -StreetAddress $StreetAddress `
                -OfficePhone $Telephone `
                -EmailAddress $Email `
                -Title $JobTitle `
                -Department $Department `
                -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
                -ErrorAction Stop

            Write-Host "Created user: $Username" -ForegroundColor Green
            $CreatedUsers++
        } catch {
            Write-Error "Failed to create user $Username. Error: $_"
        }
    }
}

# Display summary
Write-Host "`nBulk user creation completed:" -ForegroundColor Cyan
Write-Host "Users created: $CreatedUsers" -ForegroundColor Green

Write-Host "Existing users skipped: $ExistingUsers" -ForegroundColor Yellow
