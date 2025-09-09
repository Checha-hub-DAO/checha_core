<#
  Repair-Mojibake.ps1  (v1.1)
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param([Parameter(Mandatory=$true)][string]$Path,[string[]]$IncludeExt=@('.md','.log','.txt'),[switch]$Recurse,[switch]$Force,[switch]$Backup=$true)
function Normalize-Patterns{param([string[]]$exts)$p=@();foreach($e in $exts){if(-not $e){continue};$x=$e.Trim();if($x.StartsWith('*.')){$p+=$x}elseif($x.StartsWith('.')){$p+=('*'+$x)}elseif($x.Contains('*')){$p+=$x}else{$p+=('*.'+$x)}}if($p.Count-eq 0){$p=@('*.md','*.log','*.txt')};return $p}
function Test-LooksMojibaked{param([string]$s)$bad=[regex]::Matches($s,'[РС][^\x00-\x7F]').Count;$key=$s -match 'Рџ|Рє|С‚|С–|СЃ|СЏ|С‘|СЌ';return ($bad -ge 3 -or $key)}
function Get-UAHealthyScore{param([string]$s)$ua=[regex]::Matches($s,'[А-ЩЬЮЯЄІЇҐа-щьюяєіїґ]').Count;$bad=[regex]::Matches($s,'[РС][^\x00-\x7F]').Count;return $ua-$bad}
function Repair-Text{param([string]$badText)$cp1251=[System.Text.Encoding]::GetEncoding(1251);$bytes=$cp1251.GetBytes($badText);return [System.Text.Encoding]::UTF8.GetString($bytes)}
$patterns=Normalize-Patterns $IncludeExt;$pathStar=Join-Path $Path '*'
try{$files=Get-ChildItem -Path $pathStar -Include $patterns -File -Recurse:$Recurse -ErrorAction Stop}catch{Write-Host "❌ Неможливо прочитати каталог: $Path — $($_.Exception.Message)" -ForegroundColor Red;return}
if(-not $files -or $files.Count -eq 0){Write-Host ("Файлів за шаблонами: {0} не знайдено у {1}." -f ($patterns -join ', '), $Path) -ForegroundColor Yellow;return}
[int]$fixed=0;[int]$skipped=0;foreach($f in $files){try{$raw=Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop;$needFix=$Force -or (Test-LooksMojibaked $raw);if(-not $needFix){$skipped++;continue};$fixedText=Repair-Text $raw;$orig=Get-UAHealthyScore $raw;$fix=Get-UAHealthyScore $fixedText;if(-not $Force -and $fix -lt [math]::Max($orig,0)){$skipped++;continue};if($PSCmdlet.ShouldProcess($f.FullName,"Repair mojibake → UTF-8")){if($Backup){$stamp=Get-Date -Format 'yyyyMMdd_HHmmss';Copy-Item -LiteralPath $f.FullName -Destination ($f.FullName+".bak_$stamp") -ErrorAction SilentlyContinue};Set-Content -LiteralPath $f.FullName -Value $fixedText -Encoding utf8 -NoNewline:$false;$fixed++}}catch{}}Write-Host "Готово. Виправлено: $fixed; Пропущено: $skipped; Всього: $($files.Count)"
