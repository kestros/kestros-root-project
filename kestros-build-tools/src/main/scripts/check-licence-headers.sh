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
  if grep -qE '^package[[:space:]]+io\.kestros\.commons\.' "$file"; then
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
