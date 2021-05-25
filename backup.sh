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

    result_file="$SCRIPT_DIR/results/result_$configName"
    if [[ ! -d "$SCRIPT_DIR/results" ]]
    then
        eval "mkdir $SCRIPT_DIR/results"
    fi
    eval "> $result_file"
    if [[ ${#user} == 0 || ${#host} == 0 || ${#source} == 0 || ${#dest} == 0 ]]
    then
      eval "echo \"[ERROR] bad configuration\" > $result_file"
      exit 1
    fi
    bkpFolderDate=$(date +"%Y-%m-%d-%H-%M-%S")
    eval "mkdir $dest/$bkpFolderDate"
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
    limit_backup_number=$((limit_backup_number+1))
#    echo $limit_backup_number;
    eval "(cd $dest && ls -tp | tail -n +$limit_backup_number | xargs -I {} rm -r -- {})"

}

if [[ $1 != "" ]]
then
  run_config "$CONFIG_DIR/$1"
  echo "runnng configuration of $1"
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
