#!/bin/bash

CONFIG_DIR="./config.d"
CONFIG_FILES=$(ls "$CONFIG_DIR"/*)
CONFIG_NAME_REGEX='backup_name[[:space:]]([a-zA-Z0-9_./\/-]+)'
CONFIG_REPORTING='mail_report[[:space:]](YES|NO)'
CONFIG_REPORTING_ADDRESS='mail_report_address[[:space:]]([a-zA-Z0-9_./\/-]+@[a-zA-Z0-9_./\/-]+)'
USER_REGEX='user[[:space:]]([a-zA-Z0-9_-]+)'
HOST_REGEX='host[[:space:]]([a-zA-Z0-9_.-]+)'
SOURCE_REGEX='source_folder[[:space:]]([a-zA-Z0-9_./\/-]+)'
DEST_REGEX='dest_folder[[:space:]]([a-zA-Z0-9_./\/-]+)'

get_config_part() {
  if [[ "$1" =~ $2 ]]
  then
    local value="${BASH_REMATCH[1]}"
    echo "$value"
  fi
}

run_config() {
  content=$(cat "$1")
    configName=$(get_config_part "$content" "$CONFIG_NAME_REGEX")
    reporting=$(get_config_part "$content" "$CONFIG_REPORTING")
    if [[ $reporting == "YES" ]]
    then
      reporting_address=$(get_config_part "$content" "$CONFIG_REPORTING_ADDRESS")
    fi
    user=$(get_config_part "$content" "$USER_REGEX")
    host=$(get_config_part "$content" "$HOST_REGEX")
    source=$(get_config_part "$content" "$SOURCE_REGEX")
    dest=$(get_config_part "$content" "$DEST_REGEX")
    eval "> ./results/result_$configName"
    if [[ ${#user} == 0 || ${#host} == 0 || ${#source} == 0 || ${#dest} == 0 ]]
    then
      eval "echo \"[ERROR] bad configuration\" > ./results/result_$configName"
    fi
    bkpFolderDate=$(date +"%Y-%m-%d-%r")
    eval "mkdir $dest/$bkpFolderDate"
    command="rsync -avve ssh $user@$host:$source $dest/$bkpFolderDate  --log-file=./results/result_$configName --timeout=10"
    eval "$command"
    if [[  $reporting == "YES" ]]
    then
      eval "cat ./results/result_$configName | mail -s \"backup status of $configName\" $reporting_address"
    fi
}

if [[ $1 != "" ]]
then
  run_config "$CONFIG_DIR/$1"
else
  for entry in $CONFIG_FILES
  do
    if [[ "$entry" =~ 'sample' ]]
    then
      continue
    fi
    run_config $entry
  done
fi
