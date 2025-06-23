#!/bin/bash
# shellcheck disable=SC2154 # SC2154 (https://www.shellcheck.net/wiki/SC2154) is irrelevant because the variables $out, $err and $code are set by the catch function.
# shellcheck disable=SC2294 # SC2294 (https://www.shellcheck.net/wiki/SC2294) is irrelevant because replacing `eval "${@}";` by `"${@}";` changes the behavior of the script.

# Reset the Accessibility permissions if they have already been set.

# Run a functions and capture stdout, stderr and exit code, and don't exit if failed.
# https://stackoverflow.com/a/74626954/2054629
#
# Overwrites existing values of provided variables in any case.
# SYNTAX:
#   catch STDOUT_VAR_NAME STDERR_VAR_NAME EXIT_CODE_VAR_NAME COMMAND1 [COMMAND2 [...]]
function catch() {
  {
    IFS=$'\n' read -r -d '' "${1}";
    IFS=$'\n' read -r -d '' "${2}";
    IFS=$'\n' read -r -d '' "${3}";

    return 0;
  }\
  < <(
    (printf '\0%s\0%d\0' \
      "$(
        (
          (
            (
              {
                shift 3;
                eval "${@}";
                echo "${?}" 1>&3-;
              } | tr -d '\0' 1>&4-
            ) 4>&2- 2>&1- | tr -d '\0' 1>&4-
          ) 3>&1- | exit "$(cat)"
        ) 4>&1-
      )" "${?}" 1>&2
    ) 2>&1
  )
}


catch out err code "tccutil reset Accessibility \"$PRODUCT_BUNDLE_IDENTIFIER\""

if [[ $code -eq 0 ]]; then
    exit 0
elif [[ $err == *"No such bundle identifier"* ]]; then
    # The bundle doesn't need to be reset.
    echo "Bundle not found in Accessibility. No need to reset permissions"
    exit 0
else
    echo "$err" >&2
    exit "$code"
fi
