#!/usr/bin/env bash
#
#      Copyright (C) 2020  Kestros, Inc.
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#
# Checks that every Kestros Java source file carries the licence header its own package
# root calls for. The policy is in docs/LICENSING.md: io.kestros.commons is Apache 2.0,
# everything else is GPL v3, and the ASF contributor wording is wrong everywhere.
#
# Usage:
#   check-licence-headers.sh <dir>     a directory holding kestros-* clones
#   check-licence-headers.sh --self-test
#
# Exit 1 if any file carries the wrong licence for its package. Files with no header at
# all are listed separately and do not affect the exit code.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/../../../src/test/resources/licence-fixtures"

usage() {
  sed -n '22,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Prints the licence class of a Java file: ASF, APACHE, GPL or NONE.
#
# Only the text ahead of the package declaration is considered, so a file that merely
# mentions a licence in a Javadoc comment further down is not misread as carrying one.
classify_header() {
  local file="$1" head
  head="$(sed -n '1,/^package /p' "$file")"
  if [[ "$head" == *"Licensed to the Apache Software Foundation"* ]]; then
    echo ASF
  elif [[ "$head" == *"GNU General Public License"* ]]; then
    echo GPL
  elif [[ "$head" == *"Licensed under the Apache License"* ]]; then
    echo APACHE
  else
    echo NONE
  fi
}

# Prints the licence class a file's own package declaration calls for: APACHE or GPL.
expected_licence() {
  local file="$1"
  if grep -qE '^package[[:space:]]+io\.kestros\.commons([.;]|[[:space:]])' "$file"; then
    echo APACHE
  else
    echo GPL
  fi
}

# Lists the Java files to check under a root.
#
# Two modes, because the files this checks live in two shapes. "clones" walks a directory
# of repositories and takes production sources only. "flat" takes every .java file
# directly, which is how the self-test reaches its fixtures — they sit under
# src/test/resources and a clones walk would correctly skip them.
list_files() {
  local root="$1" mode="$2"
  if [[ "$mode" == "flat" ]]; then
    find "$root" -type f -name '*.java' | sort
  else
    find "$root" -type f -name '*.java' -path '*/src/main/*' | sort
  fi
}

# Writes the wrong-licence files to $1 and the missing-header files to $2.
scan() {
  local root="$1" mode="$2" wrong_out="$3" none_out="$4"
  : >"$wrong_out"
  : >"$none_out"

  local file actual expected
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    actual="$(classify_header "$file")"
    if [[ "$actual" == "NONE" ]]; then
      echo "$file" >>"$none_out"
      continue
    fi
    expected="$(expected_licence "$file")"
    # ASF wording is wrong on both sides of the line, so it never matches an expectation.
    if [[ "$actual" != "$expected" ]]; then
      printf '%s\t%s\t%s\n' "$file" "$actual" "$expected" >>"$wrong_out"
    fi
  done < <(list_files "$root" "$mode")
}

report() {
  local wrong_file="$1" none_file="$2" wrong_count none_count
  wrong_count="$(wc -l <"$wrong_file")"
  none_count="$(wc -l <"$none_file")"

  echo "=== Wrong licence for the package root ($wrong_count) ==="
  if [[ "$wrong_count" -eq 0 ]]; then
    echo "(none)"
  else
    local file actual expected
    while IFS=$'\t' read -r file actual expected; do
      printf '%s\n    has %s, package root calls for %s\n' "$file" "$actual" "$expected"
    done <"$wrong_file"
  fi

  echo
  echo "=== No header at all ($none_count) — not a failure, see docs/LICENSING.md ==="
  if [[ "$none_count" -eq 0 ]]; then
    echo "(none)"
  else
    cat "$none_file"
  fi
}

run_scan() {
  local root="$1" mode="$2" wrong none rc
  wrong="$(mktemp)"
  none="$(mktemp)"
  scan "$root" "$mode" "$wrong" "$none"
  report "$wrong" "$none"
  if [[ -s "$wrong" ]]; then rc=1; else rc=0; fi
  rm -f "$wrong" "$none"
  return "$rc"
}

# --- map ---------------------------------------------------------------------------
#
# One row per Maven module holding src/main Java sources, and one row per repository with
# none, so no repository is silently absent. Columns: repo, module, package root, expected
# licence, licence found, wrong-licence count, no-header count, verdict. A module is
# "needs work" only when a file carries the wrong licence; missing headers are counted
# but never change the verdict.

# Prints the longest dot-segment prefix shared by the package names on stdin.
common_package() {
  awk -F. '
    NR == 1 { n = NF; for (i = 1; i <= NF; i++) p[i] = $i; next }
    { m = (NF < n ? NF : n); for (i = 1; i <= m; i++) if ($i != p[i]) break; n = i - 1 }
    END { s = ""; for (i = 1; i <= n; i++) s = s (i > 1 ? "." : "") p[i]; print (s == "" ? "-" : s) }'
}

map_clones() {
  local root="${1%/}" rows file rel repo module pkg actual expected
  rows="$(mktemp)"
  while IFS= read -r file; do
    rel="${file#"$root"/}"
    repo="${rel%%/*}"
    module="${rel#"$repo"/}"
    if [[ "$module" == src/main/* ]]; then module="."; else module="${module%%/src/main/*}"; fi
    pkg="$(grep -m1 -E '^package[[:space:]]' "$file" | sed -E 's/^package[[:space:]]+([^;[:space:]]+).*/\1/')"
    actual="$(classify_header "$file")"
    expected="$(expected_licence "$file")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$repo" "$module" "${pkg:--}" "$actual" "$expected" >>"$rows"
  done < <(list_files "$root" clones)

  printf 'repo\tmodule\tpackage-root\texpected\tfound\twrong\tno-header\tverdict\n'
  local key r m root_pkg exp found wrong none
  while IFS=$'\t' read -r r m; do
    root_pkg="$(awk -F'\t' -v r="$r" -v m="$m" '$1 == r && $2 == m { print $3 }' "$rows" | common_package)"
    exp="$(awk -F'\t' -v r="$r" -v m="$m" '$1 == r && $2 == m { print $5 }' "$rows" | sort -u | paste -sd+)"
    found="$(awk -F'\t' -v r="$r" -v m="$m" '$1 == r && $2 == m && $4 != "NONE" { print $4 }' "$rows" | sort -u | paste -sd+)"
    wrong="$(awk -F'\t' -v r="$r" -v m="$m" '$1 == r && $2 == m && $4 != "NONE" && $4 != $5' "$rows" | wc -l)"
    none="$(awk -F'\t' -v r="$r" -v m="$m" '$1 == r && $2 == m && $4 == "NONE"' "$rows" | wc -l)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$r" "$m" "$root_pkg" "$exp" "${found:-none}" \
      "$wrong" "$none" "$(module_verdict "$root_pkg" "$wrong")"
  done < <(cut -f1,2 "$rows" | sort -u)

  local dir
  for dir in "$root"/*/; do
    dir="$(basename "$dir")"
    repo_has_java "$rows" "$dir" ||
      printf '%s\t-\t-\t-\t-\t0\t0\tno Java sources\n' "$dir"
  done
  rm -f "$rows"
}

# Exit 0 if the rows file holds a row for the repo.
#
# No pipe on purpose. `cut | grep -q` under pipefail reports a miss whenever grep matches
# and exits while cut is still writing: cut takes SIGPIPE and the pipeline fails. That is
# how 71 repos with Java were mapped as "no Java sources" on 2026-10-01.
repo_has_java() {
  awk -F'\t' -v r="$2" '$1 == r { found = 1; exit } END { exit !found }' "$1"
}

# Prints a module's verdict from its package root and its wrong-licence count.
#
# Code under org.apache is vendored Apache code, not a Kestros module, so the Kestros rule
# does not apply to it and its ASF headers must stay.
module_verdict() {
  local pkg="$1" wrong="$2"
  if [[ "$pkg" == org.apache.* ]]; then
    echo 'vendored, not Kestros code'
  elif [[ "$wrong" -eq 0 ]]; then
    echo correct
  else
    echo 'needs work'
  fi
}

# --- self-test ---------------------------------------------------------------------
#
# Runs the checker over the five fixtures and asserts the exact contents of both sections
# and both exit codes. It fails on a base branch where neither the script nor the
# fixtures exist, which is what makes it evidence rather than decoration.

SELF_TEST_FAILURES=0

assert_equals() {
  local what="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   — $what"
  else
    echo "FAIL — $what"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    SELF_TEST_FAILURES=$((SELF_TEST_FAILURES + 1))
  fi
}

self_test() {
  if [[ ! -d "$FIXTURE_DIR" ]]; then
    echo "FAIL — fixture directory not found: $FIXTURE_DIR"
    return 1
  fi

  local wrong none
  wrong="$(mktemp)"
  none="$(mktemp)"

  scan "$FIXTURE_DIR" flat "$wrong" "$none"

  assert_equals "wrong-licence section lists the two bad commons files" \
    "commons-asf-wrong.java commons-gpl-wrong.java" \
    "$(cut -f1 <"$wrong" | xargs -n1 basename | sort | tr '\n' ' ' | sed 's/ $//')"

  assert_equals "commons-gpl-wrong.java is reported as GPL where APACHE is called for" \
    "GPL APACHE" \
    "$(grep 'commons-gpl-wrong' "$wrong" | cut -f2,3 | tr '\t' ' ')"

  assert_equals "commons-asf-wrong.java is reported as ASF" \
    "ASF APACHE" \
    "$(grep 'commons-asf-wrong' "$wrong" | cut -f2,3 | tr '\t' ' ')"

  assert_equals "no-header section lists only the one headerless file" \
    "cms-noheader.java" \
    "$(xargs -n1 basename <"$none" | sort | tr '\n' ' ' | sed 's/ $//')"

  # The two correct files must appear in neither section.
  assert_equals "commons-apache-ok.java and cms-gpl-ok.java are not reported" \
    "" \
    "$(cat "$wrong" "$none" | grep -E 'commons-apache-ok|cms-gpl-ok' || true)"

  rm -f "$wrong" "$none"

  # Exit code, with the two failing fixtures present.
  run_scan "$FIXTURE_DIR" flat >/dev/null
  assert_equals "exit 1 when wrong-licence files are present" "1" "$?"

  # Exit code over a tree holding only the headerless fixture — a missing header on its
  # own must not fail the run.
  local clean
  clean="$(mktemp -d)"
  cp "$FIXTURE_DIR/cms-noheader.java" "$clean/"
  run_scan "$clean" flat >/dev/null
  assert_equals "exit 0 when only a missing header is present" "0" "$?"
  rm -rf "$clean"

  # A repo found on the first row of a rows file far larger than a pipe buffer must still
  # be found. This is the shape that made kestros-io-site read as "no Java sources".
  local rows
  rows="$(mktemp)"
  {
    printf 'repo-a\t.\n'
    awk 'BEGIN { for (i = 0; i < 200000; i++) printf "repo-b\tmodule\n" }'
  } >"$rows"
  repo_has_java "$rows" repo-a
  assert_equals "a repo on the first row of a large map is found" "0" "$?"
  repo_has_java "$rows" repo-c
  assert_equals "a repo with no rows is not found" "1" "$?"
  rm -f "$rows"

  assert_equals "org.apache package root is vendored, not needs work" \
    "vendored, not Kestros code" "$(module_verdict org.apache.jackrabbit.oak.plugins.document 244)"
  assert_equals "a Kestros module with wrong files needs work" \
    "needs work" "$(module_verdict io.kestros.cms.foo 3)"

  echo
  if [[ "$SELF_TEST_FAILURES" -eq 0 ]]; then
    echo "self-test passed"
    return 0
  fi
  echo "self-test failed: $SELF_TEST_FAILURES assertion(s)"
  return 1
}

# --- entry point -------------------------------------------------------------------

main() {
  if [[ $# -lt 1 ]]; then
    usage
    return 2
  fi

  case "$1" in
    --self-test)
      self_test
      ;;
    -h | --help)
      usage
      ;;
    --map)
      if [[ $# -lt 2 || ! -d "$2" ]]; then
        echo "--map needs a directory of clones" >&2
        return 2
      fi
      map_clones "$2"
      ;;
    *)
      if [[ ! -d "$1" ]]; then
        echo "not a directory: $1" >&2
        return 2
      fi
      run_scan "$1" clones
      ;;
  esac
}

main "$@"
