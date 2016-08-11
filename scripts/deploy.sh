#!/bin/bash

set -eu # please dont use -x as this will print secrets in the build log

# these env vars can be overridden by circle
CF_API=${CF_API:-https://api.system.staging.digital.gov.au}
CF_ORG=${CF_ORG:-dto}
CF_SPACE=${CF_SPACE:-angie-test}

# step 1. login to the correct org and space with cf
cf api ${CF_API}
cf auth ${CF_STAGING_USER} ${CF_STAGING_PASSWORD}
cf target -o ${CF_ORG} -s ${CF_SPACE}

# step 2. is this a PR?
if [ -z "${CI_PULL_REQUEST:-}" ] ; then
	echo "commit is not part of a pull request, skipping deploy"
	exit 0
fi

#step 4. don't create another db or app if they already exist
if (( $(cf app ${CF_APP_NAME}) == "FAILED" )) ; then
	echo "it worked"
else
	echo "no it didnt, gosh"
fi

# step 3. create and app name for this branch
GITHUB_USER_BRANCH=${CIRCLE_USERNAME}:${CIRCLE_BRANCH}
CF_APP_NAME=$(${GITHUB_USER_BRANCH}| md5sum | cut -f 1 -d ' ')
CF_SERVICE_NAME=${CF_APP_NAME}-db

# step 4. create db service and app for this branch
cf push ${CF_APP_NAME} --no-start
cf set-env ${CF_APP_NAME} CI_PULL_REQUEST ${CI_PULL_REQUEST}
cf create-service dto-shared-pgsql shared-psql ${CF_SERVICE_NAME}
cf bind-service ${CF_APP_NAME} ${CF_SERVICE_NAME}
# step 5. send generated url to github
curl -H "Authorization: token ${GITHUB_TOKEN}" --data '{ "body":"'"here is your url https://${CF_APP_NAME}.apps.staging.digital.gov.au"'"}' https://api.github.com/repos/AusDTO/cf-pgsql-sample-app/issues/1/comments

# step 6. fire!
cf start ${CF_APP_NAME}
