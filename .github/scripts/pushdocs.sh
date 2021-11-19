#!/bin/bash

PAGES_USER="rramk"
PAGES_REPO="rramtravisghtest"
PAGES_BRANCH="main"
DESTINATION_ROOT="${GITHUB_WORKSPACE}/docs"
SOURCE_ROOT="${GITHUB_WORKSPACE}/monorepo"

echo GITHUB_WORKSPACE=${GITHUB_WORKSPACE}
echo SOURCE_ROOT=${SOURCE_ROOT}
echo DESTINATION_ROOT=${DESTINATION_ROOT}

# generate privacy sdk docs
MODULE=foo
rm -rf "${DESTINATION_ROOT}/public"
DOC_TARGET_FOLDER="${DESTINATION_ROOT}/docs"
mkdir -p "${DOC_TARGET_FOLDER}"
cd "${SOURCE_ROOT}/packages/${MODULE}" && npm i && npm run docs && cd -
cp -R "${SOURCE_ROOT}/packages/${MODULE}/docs/." "${DOC_TARGET_FOLDER}/"

# configure and push to github docs repo
cd ${SOURCE_ROOT}
MESSAGE=`git log --format=%B -n 1`
cd ${DESTINATION_ROOT}
git config user.email "raghu4u449@gmail.com"
git config user.name "rramk"
git add -A
git diff-index --quiet HEAD || git commit -m "${MESSAGE}"
git push -u https://${GH_PAGES_TOKEN}@github.com/${PAGES_USER}/${PAGES_REPO}
