#!/bin/sh
test -z "${DEBUG}" || set -o xtrace
set -o errexit

test -n "${AWS_DEFAULT_REGION}" || {
  echo AWS_DEFAULT_REGION environment variable required >&2
  exit 1
}

test -n "${AWS_ACCESS_KEY_ID}" || {
  echo AWS_ACCESS_KEY_ID environment variable required >&2
  exit 1
}

test -n "${AWS_SECRET_ACCESS_KEY}" || {
  echo AWS_SECRET_ACCESS_KEY environment variable required >&2
  exit 1
}

test -n "${AWS_ACCOUNT_ID}" || {
  echo AWS_ACCOUNT_ID environment variable required >&2
  exit 1
}

write_docker_credentials () {
  user="${1}"
  password="${2}"
  url="${3}"

  auth=$(echo -n "${user}:${password}" | base64 | tr -d "\n")
  docker_file=/.docker/config.json
  work_file=$(mktemp)

  test -s "${docker_file}" || printf '{"auths":{}}' >"${docker_file}"

  jq ".auths[\"${url}\"].auth = \"${auth}\"" <"${docker_file}" >"${work_file}"
  mv -f "${work_file}" "${docker_file}"
}

parse_docker_login () {
  user=
  password=
  url=

  while test 0 -lt $#
  do
    case "${1}" in
      -u)
        user="${2}";
        shift 2;;
      -p)
        password="${2}";
        shift 2;;
      -e)
        shift 2;; # email ignored
      *)
        url="${1}"
        shift;;
    esac
  done

  test -n "${user}" || {
    echo Expected -u argument >&2
    return 1
  }
  test -n "${password}" || {
    echo Expected -p argument >&2
    return 1
  }
  test -n "${url}" || {
    echo Expected a url argument >&2
    return 1
  }

  write_docker_credentials "${user}" "${password}" "${url}"
}

refresh_credentials () {
  login_command=$(aws ecr get-login --registry-ids "${AWS_ACCOUNT_ID}")
  login_args="${login_command#docker login }"
  parse_docker_login ${login_args}
}

while true
do
  refresh_credentials
  sleep 11h
done
