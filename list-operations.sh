#!/bin/bash
set -euo pipefail

MODE="table"

if [[ "${1:-}" == "--ids-only" ]]; then
  MODE="ids"
  shift
fi

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 [--ids-only] <openapi-spec.yml>" >&2
  exit 1
fi

SPEC_FILE="$1"

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "Spec file not found: $SPEC_FILE" >&2
  exit 1
fi

LIST_OPERATIONS_MODE="$MODE" awk '
BEGIN {
  output_mode = ENVIRON["LIST_OPERATIONS_MODE"]
}

# Removes leading and trailing whitespace from a string
function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}

# Strips surrounding double or single quotes from a string after trimming whitespace
function unquote(value) {
  value = trim(value)
  if ((value ~ /^".*"$/) || (value ~ /^\047.*\047$/)) {
    return substr(value, 2, length(value) - 2)
  }
  return value
}

# Clears the current operation state to prepare for parsing a new operation
function reset_operation() {
  method = ""
  operation_id = ""
  summary = ""
}

# Outputs the current operation (as ID or table row) if complete, then resets state
function flush_operation() {
  if (current_path != "" && method != "") {
    printed_count++
    if (output_mode == "ids") {
      if (operation_id != "") {
        print operation_id
      }
    } else {
      printf "%-8s %-24s %-24s %s\n", toupper(method), current_path, (operation_id == "" ? "-" : operation_id), (summary == "" ? "-" : summary)
    }
  }
  reset_operation()
}

BEGIN {
  in_paths = 0
  paths_base = 0
  unit = 0
  current_path = ""
  printed_count = 0
  reset_operation()
  if (output_mode != "ids") {
    printf "%-8s %-24s %-24s %s\n", "METHOD", "PATH", "OPERATION ID", "SUMMARY"
    printf "%-8s %-24s %-24s %s\n", "------", "----", "------------", "-------"
  }
}

{
  line = $0
  sub(/[[:space:]]+#.*$/, "", line)

  if (line ~ /^[[:space:]]*$/) {
    next
  }

  indent_match = match(line, /[^ ]/)
  indent = indent_match > 0 ? indent_match - 1 : 0
  text = substr(line, indent + 1)

  if (!in_paths) {
    if (text == "paths:") {
      in_paths = 1
      paths_base = indent
      unit = 0
    }
    next
  }

  # Detect indent unit from the first line inside paths
  if (unit == 0 && indent > paths_base) {
    unit = indent - paths_base
  }

  if (indent <= paths_base) {
    flush_operation()
    in_paths = 0
    next
  }

  if (unit > 0 && indent == paths_base + unit && text ~ /^([\047"])?\/.*:$/) {
    flush_operation()
    current_path = text
    sub(/:$/, "", current_path)
    current_path = unquote(current_path)
    next
  }

  if (current_path != "" && unit > 0 && indent == paths_base + 2 * unit && text ~ /^(get|put|post|delete|options|head|patch|trace):$/) {
    flush_operation()
    method = text
    sub(/:$/, "", method)
    next
  }

  if (current_path != "" && method != "" && unit > 0 && indent == paths_base + 3 * unit && text ~ /^operationId:[[:space:]]*/) {
    operation_id = unquote(substr(text, index(text, ":") + 1))
    next
  }

  if (current_path != "" && method != "" && unit > 0 && indent == paths_base + 3 * unit && text ~ /^summary:[[:space:]]*/) {
    summary = unquote(substr(text, index(text, ":") + 1))
    next
  }
}

END {
  if (in_paths) {
    flush_operation()
  }

  if (printed_count == 0) {
    print "No operations found in paths section." > "/dev/stderr"
    exit 1
  }
}
' "$SPEC_FILE"