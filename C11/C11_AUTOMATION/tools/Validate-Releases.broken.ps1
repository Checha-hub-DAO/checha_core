[CmdletBinding(PositionalBinding=$false)]
$chk = Find-ChecksumForZip -Lines $checksumLines -ZipName $zip.Name
$checksumEntry = $chk.ok -and ($chk.hash -eq $shaAct)


$status = 'OK'; $msg = 'validated successfully'
if([string]::IsNullOrWhiteSpace($shaExp)){
$status = 'WARN'; $msg = 'missing SHA256 in VERSION.txt'
} elseif(-not $shaMatch){
$status = 'WARN'; $msg = 'sha mismatch'
}
if(-not $checksumEntry){
$status = if($status -eq 'OK'){'WARN'} else {$status}
$msg = if($msg -eq 'validated successfully'){ 'missing/incorrect CHECKSUMS entry' } else { $msg + '; missing/incorrect CHECKSUMS entry' }
}


$icon = if($status -eq 'OK'){'✅'}elseif($status -eq 'WARN'){'⚠️'}else{'❌'}
ColorSay ("{0} {1}: {2} ({3}) — {4}" -f $icon,$Mod,$version,$zip.Name,$msg) $status
Write-RelLog -Root $Root -Module $Mod -Version $version -Build $build -Status $status -ShaMatch:$shaMatch -ChecksumEntry:$checksumEntry -Zip $zip.Name -Msg $msg
return $status
} catch {
ColorSay ("❌ $Mod: exception — " + $_.Exception.Message) 'FAIL'
Write-RelLog -Root $Root -Module $Mod -Version 'n/a' -Build 'n/a' -Status 'FAIL' -ShaMatch:$false -ChecksumEntry:$false -Zip '' -Msg ("exception: " + $_.Exception.Message)
return 'FAIL'
}
}


# === Визначення набору модулів ===
$modsToRun = @()
if($PSCmdlet.ParameterSetName -eq 'All'){
$json = Join-Path $Root 'C06/FOCUS/data/modules.json'
$list = @()
if(Test-Path -LiteralPath $json){
try{
$data = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
if($data.modules -and $data.modules.code){ $list += $data.modules.code }
elseif($data.modules){ $list += $data.modules }
elseif($data.code){ $list += $data.code }
} catch { }
}
if(-not $list -or $list.Count -eq 0){
$list = Get-ChildItem -LiteralPath (Join-Path $Root 'G') -Directory |
Where-Object { $_.Name -match '^G\d+' } |
Select-Object -ExpandProperty Name
}
$modsToRun = $list
} elseif($PSCmdlet.ParameterSetName -eq 'List'){
$modsToRun = @()
foreach($t in $Modules){ $modsToRun += ($t -split '[,\s]+' | Where-Object {$_}) }
} else {
$modsToRun = @($Module)
}


# Нормалізація/існування/унікальність
$modsToRun = $modsToRun |
ForEach-Object { $_.Trim() } |
Where-Object { $_ -match '^G\d+' } |
Sort-Object -Unique


if(-not $modsToRun -or $modsToRun.Count -eq 0){
if(-not $Quiet){ Write-Host "Usage: .\Validate-Releases.ps1 -Module G28 | -Modules G28,G09 | -All [-Root C:\CHECHA_CORE] [-Quiet]" -ForegroundColor Yellow }
exit 3
}


# === Прогін ===
$hasWarn = $false; $hasFail = $false
foreach($m in $modsToRun){
$st = Validate-One -Root $Root -Mod $m
if($st -eq 'WARN'){ $hasWarn = $true }
elseif($st -eq 'FAIL'){ $hasFail = $true }
}


if($hasFail){ exit 2 }
elseif($hasWarn){ exit 1 }
else{ exit 0 }