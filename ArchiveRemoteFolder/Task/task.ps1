param (
    [string] $server,
    [string] $adminusr,
    [string] $adminpwd,
    [string] $sourcepath,
    [string] $targetpath,
    [string] $filename,
    [string] $datestampformat,
    [string] $retensiondays,
    [string] $excludetypeslist
)

Write-Host "Entering script task.ps1";

Write-Verbose "[server]           --> [$server]"           -Verbose;
Write-Verbose "[adminusr]         --> [$adminusr]"         -Verbose;
Write-Verbose "[sourcepath]       --> [$sourcepath]"       -Verbose;
Write-Verbose "[targetpath]       --> [$targetpath]"       -Verbose;
Write-Verbose "[filename]         --> [$filename]"         -Verbose;
Write-Verbose "[datestampformat]  --> [$datestampformat]"  -Verbose;
Write-Verbose "[excludetypeslist] --> [$excludetypeslist]" -Verbose;

### Validates all paths ###
function ValidatePath ([string]$type, [string]$path) {
    Write-Host "Validating $type Path variable.";
    if (-not $path.EndsWith("\")) { $path = "$path\"; }
    Write-Host "$type Path is $path.";
    return $path;
}

### Validates 7z file name ###
function ValidateFilename ([string]$name, [string]$format) {
    Write-Host "Validating Filename variable.";
    if (-not $name.EndsWith(".7z")) {
        $name = "$name" + "_" + (Get-Date -format $format) + ".7z";
    } else {
        $name = $name.Replace(".7z", "") + "_" + (Get-Date -format $format) + ".7z";
    }
    Write-Host "Filename is $name.";
    return $name;
}

Write-Host "Creating Script Block.";
$scriptblock = { 
    $sourcePath       = $args[0];
    $targetPath       = $args[1];
    $fileName         = $args[2];
    $retensionDays    = $args[3];
    $excludetypeslist = $args[4];

    if (-not (Test-Path $sourcePath)) { throw "Source path '$sourcePath' does not exist."; }
    if (-not (Test-Path $targetPath)) { New-Item $targetPath -Type Directory | Out-Null; }

    if ($retensionDays -ne "0") {
        $days = [Convert]::ToInt32($retensionDays, 10);
        $limit = (Get-Date).AddDays(-$days);
        Get-ChildItem $targetPath | ? { $_.Extension -eq ".7z" -and $_.CreationTime -lt $limit } | Remove-Item;
    }

    if (-not (Test-Path "$env:ProgramFiles\7-Zip\7z.exe")) { throw "$env:ProgramFiles\7-Zip\7z.exe needed"; } 
    Set-Alias 7z "$env:ProgramFiles\7-Zip\7z.exe"; 

    $exclusionlist = "";

    if ($excludetypeslist -ne "") { 
        $excludetypes = $excludetypeslist -split ',';
        foreach ($excludetype in $excludetypes) {
            $exclusionlist += "-x`!$excludetype ";
        }
    }

    Write-Host "7z a -t7z `"$targetPath$fileName`" `"$sourcePath*.*`" -r $($exclusionlist.TrimEnd())";
    cmd /c "`"$env:ProgramFiles\7-Zip\7z.exe`" a -t7z `"$targetPath$fileName`" `"$sourcePath*.*`" -r $($exclusionlist.TrimEnd())"
};

$sourcepath = ValidatePath -type "Source" -path $sourcepath;
$targetpath = ValidatePath -type "Target" -path $targetpath;
$filename   = ValidateFilename -name $filename -format $datestampformat;

[System.Management.Automation.Runspaces.PSSession] $session = $null;

Try 
{
    Write-Host "Creating Secured Credentials.";
    $credential = New-Object System.Management.Automation.PSCredential($adminusr, (ConvertTo-SecureString -String $adminpwd -AsPlainText -Force));

    Write-Host "Opening Powershell remote session on $server.";
    $session = New-PSSession -ComputerName $server -Credential $credential;

    Write-Host "Invoking 7z executable on remote server.";
    Invoke-Command -Session $session -ScriptBlock $scriptblock -ArgumentList $sourcepath, $targetpath, $filename, $retensiondays, $excludetypeslist;
}
Catch 
{
    Write-Host;
    Write-Error $_;
}
Finally 
{
    Write-Host "Closing Powershell remote session on $server.";
    if ($session -ne $null) { $session | Disconnect-PSSession | Remove-PSSession };
}

Write-Host "Leaving script task.ps1";