
# This scripts configures the network in WSL docker-desktop distribution whenever Docker Desktop starts.

Set-Location $PSScriptRoot

while ($true) {
    $pipeName = "docker_engine_linux"
    $dockerPipe = new-object System.IO.Pipes.NamedPipeClientStream '.', $pipeName , 'IN'
    try {
        Write-Host "[$(Get-Date)] Attempting to connect to $pipeName"
        $dockerPipe.Connect()
        Write-Host "[$(Get-Date)] Connect to $pipeName. Docker engine is running"

        wsl.exe -d docker-desktop -u root ./add-wsl-routes.sh

        [byte[]] $buffer = @(0) * 1024
        $readCount = 0;
        do {
            $readCount = $dockerPipe.Read($buffer, 0, $buffe.Length)
        } while ($readCount > 0)

        Write-Host "[$(Get-Date)] Disconnected from $pipeName. Assuming Docker engine was shutdown"
    } finally {
        $dockerPipe.Dispose()
    }
}