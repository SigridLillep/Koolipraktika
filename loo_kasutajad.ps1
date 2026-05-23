Import-Module ActiveDirectory

$DomainFqdn = "naised.praktika"
$BaseUsersOU = "OU=KASUTAJAD,DC=naised,DC=praktika"
$CsvPath = "C:\Scripts\kasutajad.csv"

function Ensure-OU {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$ParentDn
    )

    $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $ParentDn -SearchScope OneLevel -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "Loon OU: $Name ($ParentDn)"
        New-ADOrganizationalUnit -Name $Name -Path $ParentDn | Out-Null
    }
}

function Ensure-Group {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$PathDn
    )

    $existing = Get-ADGroup -Filter "Name -eq '$Name'" -SearchBase $PathDn -SearchScope OneLevel -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "Loon grupp: $Name ($PathDn)"
        New-ADGroup -Name $Name -GroupScope Global -GroupCategory Security -Path $PathDn | Out-Null
    }
}

function Make-LoginFromName {
    param([Parameter(Mandatory=$true)][string]$FullName)

    # eesnime esitäht + perenimi (viimane sõna)
    $parts = $FullName.Trim() -split "\s+"
    $first = $parts[0]
    $last  = $parts[$parts.Count - 1]
    (($first.Substring(0,1) + $last).ToLower())
}

# CSV: "Name","Username","Password","OU"
$rows = Import-Csv -Path $CsvPath

foreach ($r in $rows) {

    $fullName = $r.Name.Trim()
    $ouName   = $r.OU.Trim()
    $pwdPlain = $r.Password

    $login = Make-LoginFromName -FullName $fullName

    # Veendu, et OU on olemas KASUTAJAD all (kui sul on käsitsi loodud, siis ta lihtsalt leiab)
    Ensure-OU -Name $ouName -ParentDn $BaseUsersOU

    $targetOuDn = "OU=$ouName,$BaseUsersOU"

    # Grupp igale OU-le (nõue: "iga grupi liikmed ...", teeme turvaliselt nii)
    $groupName = "GRP_$ouName"
    Ensure-Group -Name $groupName -PathDn $targetOuDn

    # Kasutaja olemas?
    $existingUser = Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        Write-Host "Loon kasutaja: $login ($fullName) -> $targetOuDn"

        New-ADUser `
            -Name $fullName `
            -SamAccountName $login `
            -UserPrincipalName "$login@$DomainFqdn" `
            -Path $targetOuDn `
            -AccountPassword (ConvertTo-SecureString $pwdPlain -AsPlainText -Force) `
            -Enabled $true | Out-Null
    }
    else {
        Write-Host "Kasutaja juba olemas: $login (jätan loomise vahele)"
    }

    # Lisa gruppi
    try {
        Add-ADGroupMember -Identity $groupName -Members $login -ErrorAction Stop
        Write-Host "Lisasin gruppi: $groupName -> $login"
    }
    catch {
        Write-Host "Grupi lisamine ebaõnnestus ($groupName -> $login): $($_.Exception.Message)"
    }
}

