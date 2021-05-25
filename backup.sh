#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


CONFIG_DIR="$SCRIPT_DIR/config.d"
CONFIG_FILES=$(ls "$CONFIG_DIR"/*)
CONFIG_NAME_REGEX='backup_name[[:space:]]([a-zA-Z0-9_./\/-]+)'
CONFIG_REPORTING='mail_report[[:space:]](YES|NO)'
CONFIG_REPORTING_ADDRESS='mail_report_address[[:space:]]([a-zA-Z0-9_./\/-]+@[a-zA-Z0-9_./\/-]+)'
USER_REGEX='user[[:space:]]([a-zA-Z0-9_-]+)'
HOST_REGEX='host[[:space:]]([a-zA-Z0-9_.-]+)'
SOURCE_REGEX='source_folder[[:space:]]([a-zA-Z0-9_./\/-]+)'
DEST_REGEX='dest_folder[[:space:]]([a-zA-Z0-9_./\/-]+)'
LIMIT_BACKUP_NUMBER_REGEX='limit_backup_number[[:space:]]([0-9]+)'
COMPRESS_REGEX='compress_backup[[:space:]](YES|NO)'
RSYNC_ERROR_REGEX='rsync[[:space:]]error'

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
    limit_backup_number=$(get_config_part "$content" "$LIMIT_BACKUP_NUMBER_REGEX")
    compress=$(get_config_part "$content" "$COMPRESS_REGEX")

    if [[ ! -d "$SCRIPT_DIR/results" ]]
    then
        eval "mkdir $SCRIPT_DIR/results"
    fi

    result_file="$SCRIPT_DIR/results/result_$configName"
    if [[ ! -f "$result_file" ]]
    then
        eval "touch $result_file"
    fi
    eval "> $result_file"



    if [[ ${#user} == 0 || ${#host} == 0 || ${#source} == 0 || ${#dest} == 0 ]]
    then
      eval "echo \"[ERROR] bad configuration\" > $result_file"
      exit 1
    fi
#    If not exist try to create it
    if [[ ! -d "$dest" ]]
    then
        eval "mkdir $dest > $result_file"
    fi
#    if still not exists, exit
    if [[ ! -d "$dest" ]]
    then
        eval "echo \"[ERROR] bad configuration: dest directory not exists\" > $result_file"
      exit 1
    fi

    bkpFolderDate=$(date +"%Y-%m-%d-%H-%M-%S")
    eval "mkdir $dest/$bkpFolderDate > $result_file"
    command="rsync -avve ssh $user@$host:$source $dest/$bkpFolderDate  --log-file=$result_file --timeout=10"
    eval "$command"
    if [[  $reporting == "YES" ]]
    then
      eval "cat $result_file | mail -s \"backup status of $configName\" $reporting_address"
    fi
    if [[  $compress == "YES" ]]
    then
      eval "tar -zcf $dest/$bkpFolderDate.tgz $dest/$bkpFolderDate"
      eval "rm -r $dest/$bkpFolderDate"
    fi


    if [[ $(cat "$result_file") =~ $RSYNC_ERROR_REGEX ]]
    then
      echo "rsync failed"
      eval "rm $dest/$bkpFolderDate -r"
    else
      echo "rsync succeeded"
      limit_backup_number=$((limit_backup_number+1))
      eval "(cd $dest && ls -tp | tail -n +$limit_backup_number | xargs -I {} rm -r -- {})"
    fi

}

if [[ $1 != "" ]]
then
  echo "running configuration of $1"
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
