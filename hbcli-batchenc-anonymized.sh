#!/usr/bin/env bash

################DOCUMENTATION ONLY###################
# PURPOSE: Automate ripping of disc media via HandbrakeCLI
# USAGE:   Automatic Setup: ./hbcli-batchenc.sh
#          Manual Setup:    ./hbcli-batchenc.sh <preset> <title>
# INPUT:   Automatic Setup: NONE
#          Manual Setup:    Handbrake preset and/or disc title
#
# OUTPUT:  Automatic Setup: MP4 file using preset at /outDir/title-#.mp4
#          Manual Setup:    MP4 file using specified preset at /path/
#
# READ:    Lines with !AUTOMATIC should be commented out for manual use
#          Lines with !MANUAL must be uncommented and have values
#          Lines with !REMOTE should be commented out for local use
#          If using AUTOMATIC, use a staging area for media and organize after rip
#
# WIP:     Update for using on server (no remote)
#          Figure out how to auto-start on Ubuntu Server 20.04
#          Any way to connect to a DB for naming search?
#          Add flag for remote/local

########################################################################
########################### CHANGE THESE ###############################
########################################################################

# comment out if not using rip local --> store remote
user_name=<remote_host_username>
remote_host=<remote_host_ip_or_name>

# need path to Handbrake presets (can be anywhere)
hbDir=</path/to/handbrake/presets/>

# where is media stored e.g., /mnt/dvd-storage/
baseDir=</path/to/media/>

# what are your prefix names e.g., plex-DVD-[media_type]
# name all presets similar or use single preset
preset_prefix=<preset-naming-convention->

# set minimum title duration from disc to process (integer)
min_dur=<minimum_duration>

# !AUTOMATIC
# output folder for automatic storage
media=<media_store_folder_name>

# !MANUAL
# media is preset name AND media directory
# title is manual disc title input (useful for plex)
#media="$1"
#title="$2"

########################################################################
########################### DO NOT CHANGE ##############################
########################################################################

# !REMOTE
# scp to a remote destination (can comment out in loop rather than here)
# current usage is rip on different computer than server, will be updated
function scpubu () {
  folder=$(printf %q "$3")
  destDir="$2"/"${folder}"/
  ssh "${user_name}"@"${remote_host}" mkdir -p "${destDir}"
  scp "$1" "${user_name}"@"${remote_host}":"${destDir}"
}

# grab disc title for auto-naming purposes
title=$(diskutil info <DISC_DRIVE> | sed -n -e 's/^.*Volume Name: //p' | xargs)

# current usage is media type for folder name (movies vs. tv_shows)
dirSlug="${media}/${title}"

# e.g., plex-DVD-movies.json OR plex-DVD-storage.json
preset="${preset_prefix}${media}"
presetDir="${hbDir}${preset}.json"

# usage is for mounted media storage (/mnt/name/[movies OR tv_shows]/[disc_title])
outDir="${baseDir}${dirSlug}/"

# make HandbrakeCLI error for each title not 0, store errors in variable
rawout=$(handbrakeCLI -i <DISC_DRIVE> --min-duration=0 -t 0 2>&1 >/dev/null)

# count the error lines for total title count
count=$(echo $rawout | grep -Eao "\\+ title [0-9]+:" | wc -l)

# make output directory and any missing parents
mkdir -p "${outDir}"

# iterate through titles
for i in $(seq $count); do
  episode="${outDir}${title}-$i.mp4"
  handbrakeCLI \
  --preset-import-file "${presetDir}" \
  --preset ${preset} \
  -i <DISC_DRIVE> -t $i --min-duration="${min_dur}" -o "${episode}"
  # !REMOTE (comment out next 2 lines)
  scpubu "${episode}" "${media}" "${title}"
  rm "${episode}"
done

rm -r "${outDir}"

drutil eject <DISK_DRIVE>
