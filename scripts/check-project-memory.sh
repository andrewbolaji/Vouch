#!/bin/sh
set -eu

memory_mode=${1:-structure}

if [ "$memory_mode" != "structure" ] && [ "$memory_mode" != "--staged" ]; then
  echo "Usage: $0 [--staged]" >&2
  exit 2
fi

memory_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
memory_candidate_root=$(CDPATH= cd -- "$memory_script_dir/.." && pwd)

if memory_git_root=$(git -C "$memory_candidate_root" rev-parse --show-toplevel 2>/dev/null); then
  memory_project_root=$memory_git_root
else
  memory_project_root=$memory_candidate_root
fi

memory_failed=0

for memory_file in docs/EXECUTION.md docs/LEARNINGS.md docs/INTERFACE.md; do
  if [ ! -f "$memory_project_root/$memory_file" ]; then
    echo "Missing project memory: $memory_file" >&2
    memory_failed=1
  fi
done

if [ ! -f "$memory_project_root/AGENTS.md" ]; then
  echo "Missing AGENTS.md project instructions" >&2
  memory_failed=1
else
  for memory_reference in docs/EXECUTION.md docs/LEARNINGS.md docs/INTERFACE.md; do
    if ! grep -F "$memory_reference" "$memory_project_root/AGENTS.md" >/dev/null 2>&1; then
      echo "AGENTS.md does not reference $memory_reference" >&2
      memory_failed=1
    fi
  done
fi

if [ "$memory_failed" -ne 0 ]; then
  exit 1
fi

if [ "$memory_mode" = "--staged" ]; then
  if ! git -C "$memory_project_root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "--staged requires a Git repository" >&2
    exit 2
  fi

  memory_has_implementation_change=0
  memory_staged_paths=$(git -C "$memory_project_root" diff --cached --name-only --diff-filter=ACMR)

  for memory_path in $memory_staged_paths; do
    case "$memory_path" in
      docs/*|*.md|*.txt|LICENSE*|.gitignore|.gitattributes)
        ;;
      *)
        memory_has_implementation_change=1
        ;;
    esac
  done

  if [ "$memory_has_implementation_change" -eq 1 ] && [ "${PROJECT_MEMORY_LANE:-}" != "0" ]; then
    if git -C "$memory_project_root" diff --cached --quiet -- docs/EXECUTION.md; then
      echo "Staged implementation changes require a staged docs/EXECUTION.md update." >&2
      echo "For a confirmed mechanical change, rerun with PROJECT_MEMORY_LANE=0." >&2
      exit 1
    fi
  fi
fi

echo "Project memory contract passes."
