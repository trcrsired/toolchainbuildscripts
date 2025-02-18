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

# Run the install-llvm script and check its exit code
Run-Command "./install-llvm.ps1 -DOWNLOADALL no -NOINSTALLING yes"
