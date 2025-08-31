#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
STAMP_REGEX='_Stamp:_ .+ v[0-9]+\.[0-9]+ · [0-9]{4}-[0-9]{2}-[0-9]{2} · .+'
IGNORE_DIRS=( ".git" "node_modules" "release" "dist" ".github" "build" )

mapfile -t files < <(find "$ROOT" -type f \( -iname "*.md" -o -iname "*.markdown" \))

should_ignore() {
  local p="$1"
  for d in "${IGNORE_DIRS[@]}"; do
    [[ "$p" == *"/$d/"* ]] && return 0
  done
  return 1
}

bad=()
for f in "${files[@]}"; do
  should_ignore "$f" && continue
  head -n 200 "$f" | grep -E -q "$STAMP_REGEX" || bad+=("$f")
done

if (( ${#bad[@]} > 0 )); then
  echo "❌ Відсутній або невалідний штамп у файлах:"
  for b in "${bad[@]}"; do echo " - $b"; done
  echo
  echo "Очікуваний формат:"
  echo "_Stamp:_ NAME vX.Y · YYYY-MM-DD · Автор"
  exit 1
fi

echo "✅ Усі штампи валідні."
