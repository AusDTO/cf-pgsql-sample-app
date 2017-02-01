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
else
	#step 3. create app and service name
	GITHUB_USER_BRANCH=${CIRCLE_USERNAME}:${CIRCLE_BRANCH}
	CF_APP_NAME=$( ${GITHUB_USER_BRANCH} | md5sum | cut -f 1 -d ' ')
	CF_SERVICE_NAME=${CF_APP_NAME}-db

	cf app ${CF_APP_NAME} && cf service ${CF_SERVICE_NAME}
	#step 4. create environment if db and app doesn't exist
	if [ $? -ne 0 ]; then
		echo "build all the things"
		# step 4.1 create db and bind to app
		cf push ${CF_APP_NAME} --no-start
		cf set-env ${CF_APP_NAME} CI_PULL_REQUEST ${CI_PULL_REQUEST}
		cf create-service dto-shared-pgsql shared-psql ${CF_SERVICE_NAME}
		cf bind-service ${CF_APP_NAME} ${CF_SERVICE_NAME}
		#step 4.2 get PR number so we can comment back to it
		PR_NUMBER=$(echo ${CI_PULL_REQUEST} | sed 's/[^0-9]*//g')
		cf set-env ${CF_APP_NAME} CI_PR_NUMBER ${CI_PR_NUMBER}
		# step 4.3 send generated url to github
		curl -H "Authorization: token ${GITHUB_TOKEN}" --data '{ "body":"'"here is your url https://${CF_APP_NAME}.apps.staging.digital.gov.au"'"}' https://api.github.com/repos/AusDTO/cf-pgsql-sample-app/issues/${CI_PR_NUMBER}/comments

		# step 4.4. start app
		cf start ${CF_APP_NAME}
	else
		# step 5 only push changes if db and app already exist for this PR
		echo "only push"
	  cf push ${CF_APP_NAME}
	fi
fi


# #step 6 if pr is merged spin sown app and db
# curl https://api.github.com/repos/AusDTO/cf-pgsql-sample-app/
#
# GET /repos/:owner/:repo/pulls/:number/merge
# Response if pull request has been merged
#
# Status: 204 No Content
# Response if pull request has not been merged
#
# Status: 404 Not Found

#todo
#make pr number dynamic
