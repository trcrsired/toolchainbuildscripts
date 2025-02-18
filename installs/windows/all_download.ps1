# Please run the following command to allow the script to run:
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Function to run a command and check its exit code
function Run-Command {
    param (
        [string]$command
    )

    Invoke-Expression $command
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$command failure"
        exit 1
    }
}

# Set the environment variable
$env:DOWNLOAD_ALL = "yes";
$env:NOINSTALLING = "no";

# Run the install-llvm script and check its exit code
Run-Command "./install-llvm.ps1"

# Run the create_cfgs script
Run-Command "./create_cfgs.ps1"
