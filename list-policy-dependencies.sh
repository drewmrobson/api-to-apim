#!/bin/bash
# Extracts dependencies from Azure API Management policy XML files.
# Parses fragment-id attributes and {{namedValue}} placeholders to identify
# policy fragments and named values that the policy depends on.
# Outputs as a formatted table (default), or filtered lists with --fragments-only / --named-values-only.
set -euo pipefail

MODE="table"
if [[ "${1:-}" == "--fragments-only" ]]; then
  MODE="fragments"
  shift
elif [[ "${1:-}" == "--named-values-only" ]]; then
  MODE="named-values"
  shift
fi

POLICY_FILE="${1:?Usage: $0 [--fragments-only|--named-values-only] <policy.xml>}"

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "Policy file not found: $POLICY_FILE" >&2
  exit 1
fi

# ── Fragments ──────────────────────────────────────────────────────────────────

mapfile -t FRAGMENTS < <(
  grep -oE 'fragment-id="[^"]+"' "$POLICY_FILE" \
    | sed 's/fragment-id="//;s/"//' \
    | sort -u || true
)

if [[ "$MODE" == "fragments" ]]; then
  for fragment in "${FRAGMENTS[@]}"; do
    echo "$fragment"
  done
  exit 0
fi

if [[ "$MODE" == "table" ]]; then
  echo "Fragments"
  echo "---------"
  if [[ ${#FRAGMENTS[@]} -eq 0 ]]; then
    echo "(none)"
  else
    for fragment in "${FRAGMENTS[@]}"; do
      echo "  $fragment"
    done
  fi
fi

# ── Named Values ───────────────────────────────────────────────────────────────

mapfile -t NAMED_VALUES < <(
  grep -oE '\{\{[^}]+\}\}' "$POLICY_FILE" \
    | sed 's/{{//;s/}}//' \
    | sort -u || true
)

if [[ "$MODE" == "named-values" ]]; then
  for nv in "${NAMED_VALUES[@]}"; do
    echo "$nv"
  done
  exit 0
fi

echo ""
echo "Named Values"
echo "------------"
if [[ ${#NAMED_VALUES[@]} -eq 0 ]]; then
  echo "(none)"
else
  for nv in "${NAMED_VALUES[@]}"; do
    echo "  $nv"
  done
fi
