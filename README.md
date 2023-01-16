# Access Kubernetes Pods on Docker Desktop directly from Windows

Run the following commands from windows

1. Run the following script once as Administrator to add the permenent routing rules for pod and cluster ip ranges

    powershell ./add-win-routes.ps1

2. Run the following script everytime after starting Docker Desktop

    wsl -d docker-desktop -u root ./add-wsl-routes.sh