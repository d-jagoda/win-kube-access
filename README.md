# Access Kubernetes Pods on Docker Desktop directly from Windows

## Configure Windows/WSL

1. Copy the content of the repo to a local directory on Windows
2. Run the following powershell script to configure Windows and WSL

        powershell.exe ./setup.ps1


## Manually configure Windows/WSL (INCOMPLETE)

Run the following commands from Windows

1. Run the following script once as Administrator to add the permenent routing rules for pod and cluster ip ranges

        powershell.exe ./add-win-routes.ps1

2. Run the following script everytime after starting Docker Desktop

        wsl.exe -d docker-desktop -u root ./add-wsl-routes.sh
        