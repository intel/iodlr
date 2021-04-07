# $1: message
# $2: exit code
die() {
  echo "$1"
  exit $2
}

# $1: binary
# $2: name of file containing expected output
test_stdout() {
  BINARY="$1"
  EXPECTED="$2"

  OUTPUT=$(mktemp)
  "${BINARY}" > "${OUTPUT}" 2>&1
  diff -u "${OUTPUT}" "${EXPECTED}"
  RESULT=$?

  rm -f "${OUTPUT}"
  return ${RESULT}
}

get_make() {
  if test "x$(uname -s)x" != "xFreeBSDx"; then
    echo "make"
  else
    echo "gmake"
  fi
}
