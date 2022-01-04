#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


CONFIG_DIR="$SCRIPT_DIR/config.d"
CONFIG_FILES=("$CONFIG_DIR"/*)
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
RECEIVED_REGEX='received[[:space:]]([0-9,]+)[[:space:]]bytes'
ERROR=false

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

    mkdir -p "$SCRIPT_DIR/results"

    result_file="$SCRIPT_DIR/results/result_$configName"

    if [ ! -f "$result_file" ]; then touch "$result_file"; fi
    echo "" > "$result_file"

    missing_config_values=()
    for config_values in user host source dest
    do test "${!config_values}" || missing_config_values+=("$config_values")
    done
    if [ "${missing_config_values[*]}" ]
    then
        printf '[ERROR] configuration missing value for "%s"\n' "${missing_config_values[@]}" |
            tee "$result_file" >&2
        exit 1
    fi

#    If not exist try to create it
    mkdir -p "$SCRIPT_DIR/results"
    mkdir -p "$dest"

    if [[ ! -d "$dest" ]]
    then
      echo "[ERROR] bad configuration: dest directory does not exists and cannot be created" | tee "$result_file" >&2
      exit 1
    fi

    bkpFolderDate=$(date +"%Y-%m-%d-%H-%M-%S")
    mkdir "$dest/$bkpFolderDate" > "$result_file" #not sure it returns something

    rsync -avve ssh "$user"@"$host":"$source" "$dest"/"$bkpFolderDate"  --log-file="$result_file" --timeout=10

    if [ $compress == "YES" ]
    then
      tar -zcf "$dest/$bkpFolderDate.tgz $dest/$bkpFolderDate"
      rm -r "$dest/$bkpFolderDate"
    fi

    if [[ $(cat "$result_file") =~ $RSYNC_ERROR_REGEX ]]
    then
      echo "rsync failed"
      rm -r "$dest/$bkpFolderDate"
      ERROR=true
    else
      echo "rsync succeeded"
      limit_backup_number=$((limit_backup_number+1))
      cd "$dest" && ls -tp | tail -n +"$limit_backup_number" | xargs -I {} rm -r -- {}
    fi

    if [ $reporting == "YES" ]
    then
      if [ $ERROR == true ];then error_title="[ERROR]";else error_title="";fi
      if [[ $(cat "$result_file") =~ $RECEIVED_REGEX ]];then received="${BASH_REMATCH[1]}";else received="0";fi
      received=$(echo "$received" | sed 's/,//g')
      receivedInMo=$((received/1048576))
#      cat "$result_file" | mail -s "$error_title backup status of $configName ($receivedInMo Mo)" "$reporting_address"
      echo -e "Subject: $error_title backup status of $configName ($receivedInMo Mo)\n\n$(<$result_file)" | sendmail "$reporting_address"
    fi
}

if [[ $1 != "" ]]
then
  echo "running configuration of $1"
  run_config "$CONFIG_DIR/$1"
else
  for entry in "${CONFIG_FILES[@]}"
  do
    [[ "$entry" =~ 'sample' ]] || run_config $entry
  done
fi
