#!/usr/bin/env bash
resolve_resume() {
  local root="$1"
  local input="$2"

  # Numeric index → find the Nth conf
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    local i=0
    local lang=""
    for conf in "$root"/configs/resumes/*.conf; do
      [[ -f "$conf" ]] || continue
      i=$((i + 1))
      if [[ "$i" -eq "$input" ]]; then
        lang="$(basename "$conf" .conf)"
        break
      fi
    done
    if [[ -z "$lang" ]]; then
      echo "error: no resume at index $input (run 'bash scripts/resume.sh list' to see valid numbers)" >&2
      return 1
    fi
    echo "$lang"
    return 0
  fi

  # Direct lang code
  if [[ ! -f "$root/configs/resumes/${input}.conf" ]]; then
    echo "error: unknown resume lang '$input' (no configs/resumes/${input}.conf)" >&2
    return 1
  fi
  echo "$input"
}
