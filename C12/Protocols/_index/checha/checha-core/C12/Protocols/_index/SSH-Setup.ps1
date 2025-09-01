# Setup Git SSH with ed25519 on Windows
Param(
    [string]$Comment = "serge",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
)
$pub = "$KeyPath.pub"
if (-not (Test-Path $KeyPath)) {
    ssh-keygen -t ed25519 -C $Comment -f $KeyPath -N ""
    Write-Host "Generated SSH key: $KeyPath"
} else {
    Write-Host "SSH key already exists: $KeyPath"
}
# Ensure agent is running
Get-Service ssh-agent -ErrorAction SilentlyContinue | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $KeyPath

# Output public key for GitHub
Write-Host "`n=== Public key (copy to GitHub → Settings → SSH keys) ===" -ForegroundColor Cyan
Get-Content $pub

Write-Host "`nNow test:" -ForegroundColor Yellow
Write-Host "  ssh -T git@github.com"
Write-Host "You should see a success/auth prompt."

# С.Ч.
