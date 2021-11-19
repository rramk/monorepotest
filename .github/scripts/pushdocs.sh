#!/bin/bash

pwd
ls ${GITHUB_WORKSPACE}
cd ${GITHUB_WORKSPACE}/monorepo/packages/foo && npm i && npm run docs && cd -
PAGES_USER="rramk"
PAGES_REPO="rramtravisghtest"
PAGES_BRANCH="main"
GH_REPO="github.com/${PAGES_USER}/${PAGES_REPO}.git"
MESSAGE=$(git log --format=%B -n 1)
cd ${RUNNER_TEMP}
git clone git://${GH_REPO}
cd ${PAGES_REPO}
git checkout ${PAGES_BRANCH} || git checkout -b ${PAGES_BRANCH}
DOC_TARGET_FOLDER="docs"
rm -rf ${DOC_TARGET_FOLDER}/*
mkdir -p ${DOC_TARGET_FOLDER}

pwd
ls -al
ls -al ../
ls -al ../../
DECRYPTED_TOKEN = `echo ${GH_PAGES_TOKEN} | sed 's/./&/g'`
echo "${DECRYPTED_TOKEN}"
echo "${MESSAGE}"
echo ${GH_PAGES_TOKEN} | sed 's/./&/g'

cp -R ${GITHUB_WORKSPACE}/monorepo/packages/foo/docs/. ${DOC_TARGET_FOLDER}/


ls -al ${DOC_TARGET_FOLDER}

git config user.email "raghu4u449@gmail.com"
git config user.name "rramk"

git add -A
git diff-index --quiet HEAD || git commit -m "${MESSAGE}"
git push -u https://${PAGES_USER}:${GH_PAGES_TOKEN}@github.com/rramk/rramtravisghtest

