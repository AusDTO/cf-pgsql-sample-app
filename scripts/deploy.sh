#!/bin/bash

set -eu # please dont use -x as this will print secrets in the build log


# these env vars can be overridden by circle
CF_API=${CF_API:-https://api.system.staging.digital.gov.au}
CF_ORG=${CF_ORG:-dto}
CF_SPACE=${CF_SPACE:-dfc-test}

# step 1. login to the correct org and space with cf
cf api ${CF_API}
cf auth ${CF_STAGING_USER} ${CF_STAGING_PASSWORD}
cf target -o ${CF_ORG} -s ${CF_SPACE}

# step 2. is this a PR? 
if [ -z "${CI_PULL_REQUEST:-}" ] ; then
	echo "commit is not part of a pull request, skipping deploy"
	exit 0
fi

# step 3. create db service and app for this branch
CF_APP_NAME=${CIRCLE_PROJECT_REPONAME}-$(git rev-parse --short ${CIRCLE_SHA1})
CF_SERVICE_NAME=${CIRCLE_PROJECT_REPONAME}-$(git rev-parse --short ${CIRCLE_SHA1})-db

cf push ${CF_APP_NAME} --no-start
cf set-env ${CF_APP_NAME} CI_PULL_REQUEST ${CI_PULL_REQUEST}
cf create-service dto-shared-pgsql shared-psql ${CF_SERVICE_NAME}
cf bind-service ${CF_APP_NAME} ${CF_SERVICE_NAME}

# step 4. fire!
cf start ${CF_APP_NAME}
