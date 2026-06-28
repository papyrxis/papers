#!/usr/bin/env bash
resolve_paper() {
  local root="$1"
  local input="$2"

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    local i=0
    local slug=""
    for conf in "$root"/configs/papers/*.conf; do
      [[ -f "$conf" ]] || continue
      i=$((i + 1))
      if [[ "$i" -eq "$input" ]]; then
        slug="$(basename "$conf" .conf)"
        break
      fi
    done
    if [[ -z "$slug" ]]; then
      echo "error: no paper at index $input (run 'make list' to see valid numbers)" >&2
      return 1
    fi
    echo "$slug"
    return 0
  fi

  if [[ ! -f "$root/configs/papers/${input}.conf" ]]; then
    echo "error: unknown paper '$input' (no configs/papers/${input}.conf)" >&2
    return 1
  fi
  echo "$input"
}