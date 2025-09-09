# --- Release: idempotent create-or-update ---
$exists = $false
try {
  gh release view $tag --json tagName | Out-Null
  $exists = $true
} catch {
  $exists = $false
}

$flags = @()
if($cfg.GitHub.Draft){ $flags += "--draft" }
if($cfg.GitHub.Prerelease){ $flags += "--prerelease" }

if(-not $exists){
  gh release create $tag $report $checks --title $name --notes-file $tmpNotes @flags | Out-Null
  "OK: created release $tag"
} else {
  # оновити мета-інфо (title/notes) + перезалити ассети
  gh release edit $tag --title $name --notes-file $tmpNotes @flags | Out-Null
  gh release upload $tag $report $checks --clobber | Out-Null
  "OK: updated release $tag (notes/assets)"
}
