#!/bin/bash
# Copyright (C) 2019 Rama Bondan Prakoso (rama982)
# Scripts to merge / upstream kernel drivers (wifi and audio)
# for msm-4.4+

while (( ${#} )); do
  case ${1} in
       "-a"|"--audio") AUDIO=true ;;
       "-i"|"--init") INIT=true ;;
       "-w"|"--wlan") WLAN=true ;;
       "-p"|"--prima") PRIMA=true ;;
       "-d"|"--data") DATA=true ;;
       "-t"|"--tag") shift; TAG=${1} ;;
       "-u"|"--update") UPDATE=true ;;
  esac
  shift
done

[[ -n ${INIT} && -n ${UPDATE} ]] && { echo "Both init and update were specified!"; exit; }

[[ -z ${TAG} ]] && { echo "No tag was specified!"; exit; }

function drivers()
{
  if [[ $4 == "wlan" ]]; then
     PREFIX="staging"
     NAME="$1/$3"
  else
     PREFIX=techpack
     NAME=$1
  fi
  echo "${3}"
  git fetch "$2/$3" "${TAG}"
  if [[ -n ${INIT} ]]; then
    git subtree add --prefix="${NAME}" FETCH_HEAD
    [[ $? -eq 1 ]] && { exit; }
    git commit --amen -m "${PREFIX}: ${3}: Add from ${TAG}" -s
  elif [[ -n ${UPDATE} ]]; then
    git merge --no-edit -m "${PREFIX}: ${3}: Merge tag '${TAG}' into $(git rev-parse --abbrev-ref HEAD)"  \
              -m "$(git log --oneline --no-merges $(git branch | grep "\*" | sed 's/\* //')..FETCH_HEAD)" \
              -X subtree="${NAME}" --signoff FETCH_HEAD
  fi
}

if [[ -n ${WLAN} ]]; then
  SUBFOLDER_WLAN=drivers/staging
  URL_WLAN=https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan
  if [[ -z ${PRIMA} ]]; then
    REPOS_WLAN=( "fw-api" "qcacld-3.0" "qca-wifi-host-cmn" )
  else
    REPOS_WLAN=( "prima" )
  fi
  for REPO in "${REPOS_WLAN[@]}"; do
    drivers $SUBFOLDER_WLAN $URL_WLAN $REPO wlan
  done
fi

if [[ -n ${AUDIO} ]]; then
  SUBFOLDER_AUDIO=techpack/audio
  REPO_AUDIO=( "audio-kernel" )
  URL_AUDIO=https://source.codeaurora.org/quic/la/platform/vendor/opensource
  drivers $SUBFOLDER_AUDIO $URL_AUDIO $REPO_AUDIO
fi

if [[ -n ${DATA} ]]; then
  SUBFOLDER_DATA=techpack/data
  REPO_DATA=( "data-kernel" )
  URL_DATA=https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource
  drivers $SUBFOLDER_DATA $URL_DATA $REPO_DATA
fi
