param(
  [Parameter(Mandatory=$true)][string]$Id,
  [Parameter(Mandatory=$true)][string]$Topic,
  [string]$Owner = "Owner",
  [ValidateSet("draft","active","archived","closed")][string]$Status = "draft",
  [string]$Version = "v0.1",
  [string]$Tags = "",
  [string]$Root = "C:\CHECHA_CORE\C12\Protocols"
)
$dir = Join-Path $Root $Status
if(!(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$slug = ($Topic -replace "[^\p{L}\p{Nd}\- ]","").Trim() -replace " +","-"
$file = Join-Path $dir ("{0}_{1}.md" -f $Id,$slug)
$now  = Get-Date
$iso  = $now.ToString("yyyy-MM-ddTHH:mm:ssK")
$yaml = @"
---
id: $Id
topic: $Topic
status: $Status
owner: "$Owner"
version: $Version
tags: [$Tags]
created_at: $iso
updated_at: $iso
---
"@
$body = @"
# Протокол $Id

## 1. Суть
## 2. Межі й правила
## 3. План дій
## 4. Артефакти / посилання
## 5. Лог оновлень
- $($now.ToString("yyyy-MM-dd HH:mm")) — створено каркас ($Owner)
"@
$enc = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($file, ($yaml + "`r`n" + $body), $enc)
Write-Host "✅ Створено протокол: $file"
# авто-реіндекс
& (Join-Path $Root "_index\protocol_reindex_from_files.ps1") | Out-Null