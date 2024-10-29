#!/bin/bash

# This script monitors specified directories for file deletions and sends email alerts if any deletions are detected.
# It also performs periodic connection tests and sends alerts if the connection is inactive.

# Functions:
# - rearray: Copies an associative array.
# - email: Sends an email using a specified template.
# - alert: Triggers an email alert based on the type of alert (connection, startup, or data loss).
# - generate_report: Generates a report of deleted files.
# - check: Identifies deletions and generates reports and summaries.
# - connection_test: Checks the connection status and sends an alert if inactive.
# - write_state: Writes the current state of the monitored directories to a file.
# - read_state: Loads monitored directories and previous state from a file.
# - startup: Initializes the monitoring process and triggers a startup alert.
# - monitord: Directory monitor daemon, runs the monitoring process.
# - parameter_check: Checks if required parameters are present in the configuration file.

# Main:
# - Sets up logging.
# - Reads configuration from conf/monitor.conf.
# - Creates necessary directories.
# - Starts the monitoring process.

#### functions ####

# copy associative array
rearray () {
    tmp=$(declare -p "$1")
    tmp=${tmp/-A/-Ag}
    eval "${tmp/$1/$2}"
}

# send email
email () {
    printf "[%s] %s\n" "$(date)" "sending email"
    # select template
    if [[ "$report" == "TRUE" ]]; then
        template=src/email.template
    else
        template=src/email.template.short
    fi

    # generate email
    cat $template | \
        sed "s|To|To: $1|" | \
        sed "s|From|From: $2|" | \
        sed "s|Subject|Subject: $3|" | \
        sed "s|body|$4|" > latest/email.txt
    
    if [[ "$report" == "TRUE" ]]; then
        attachment=$(base64 -w 0 latest/report.txt)
        sed -e '/SUMMARY/{' -e "r latest/summary.txt" -e 'd' -e '}' -i latest/email.txt
        sed -i "s|file_contents|$attachment|" latest/email.txt
    fi

    # send email
    ssmtp -t < latest/email.txt
}

# send email alert
alert () {
    printf "[%s] %s %s\n" "$(date)" "alert:" "$1"
    if [[ $1 == "connection" ]]; then
        subject="$connection_test_subject"
        body="----- Start of message ----- \n\n$connection_test_body$connection \n\n----- End of message -----"
    elif [[ $1 == "startup" ]]; then
        subject="$startup_subject"
        body="----- Start of message ----- \n\n$startup_body \n\nFiles being monitored: \n$dirs_str \n\n----- End of message -----"
    elif [[ $1 == "data_loss" ]]; then
        subject="$data_loss_subject"
        body="----- Start of message ----- \n\n$data_loss_body \nFull report attached and available at: $copy_dir \nSee summary below. \n\nSUMMARY \n\n----- End of message -----\n" 
    fi
    email "$email_recipients" "$email_source" "$subject" "$body"
}

# get info of deletions
generate_report() {
    info_arr=()
    for file in $removed; do
        file_info=$(echo "${stat1[$dir]}" | grep -w "File: $file$" -A 7)
        info_arr+=("$file_info\n\n")
    done

    
    header=$(echo -e "##### ----- $dir ----- #####\nMissing files: $n_missing")
    content=$(echo -e "${info_arr[*]}")
    printf "\n%s\n---\n%s" "$header" "$content" 
}

# identify deletions
check () {
    printf "[%s] %s\n" "$(date)" "checking for deletions"
    reports=()
    summaries=()

    len=${#chsum1[@]}
    for i in $(seq 0 $((len - 1))); do
        dir=${dirs[$i]}
        change=$(diff -Bw <(echo "${chsum1[$dir]}") <(echo "${chsum2[$dir]}"))
        removed=$(echo "$change" | grep "< File:" | sed "s/< File://g")

        if [[ "$removed" != "" ]]; then
            n_missing=$(echo "$removed" | wc -l)
            printf "[%s] %s %s %s\n%s\n" "$(date)" "$n_missing" "deletions detected in" "$dir" "$removed"
            reports[i]=$(generate_report)
            summaries[i]=$(echo -e "$removed")
            report=TRUE
        fi
    done

    if [[ "$report" == "TRUE" ]]; then
        printf "[%s] %s\n" "$(date)" "compiling reports"
        mkdir -p reports/"$t_short"
        n_files=$(find reports/"$t_short"/report* -type f | wc -l)
        report_loc=reports/$t_short/report_$n_files.txt
        summary_loc=reports/$t_short/summary_$n_files.txt

        printf "Data loss summary - %s\n" "$(date)" > "$summary_loc"
        printf "\n%s\n" "${summaries[@]}" >> "$summary_loc"
        printf "Data loss report - %s" "$(date)" > "$report_loc"
        printf "\n%s\n" "${reports[@]}" >> "$report_loc"


        cat "$summary_loc" > latest/summary.txt
        cat "$report_loc" > latest/report.txt

        alert data_loss
        report=FALSE
    else
        printf "[%s] %s\n" "$(date)" "no deletions detected"
    fi
}

# handshake alert
connection_test () {
    printf "[%s] %s\n" "$(date)" "running connection test"
    if [ ! -d $handshake_dir ]; then
        printf "[%s] %s\n" "$(date)" "connection inactive"
        connection="INACTIVE"
        alert connection
    else
        printf "[%s] %s\n" "$(date)" "connection active"
        connection="ACTIVE"
        if [[ "$((count % $periodic_check))" == 0 ]]; then
            printf "[%s] %s\n" "$(date)" "running periodic connection alert"
            alert connection
        fi
    fi
}

# write state to file
write_state () {
    printf "[%s] %s\n" "$(date)" "writing state to file"
    tmp=$(declare -p stat1)
    tmp=${tmp/-A/-Ag}
    echo "$tmp" > latest/state_file.txt

}

# load monitored directories and previous state
read_state () {
    printf "[%s] %s\n" "$(date)" "checking for state file"
    readarray -t dirs < "$monitor_file"
    declare -gA stat2
    declare -gA chsum1
    declare -gA chsum2

    if [ -f latest/state_file.txt ]; then
        printf "[%s] %s\n" "$(date)" "state file found. loading in previous file array"
        source latest/state_file.txt # load stat1
        for dir in "${dirs[@]}"; do
            status=${stat1[$dir]}
            chsum1[$dir]=$(echo "$status" | grep File | sed "s/ //g")
        done   
    else
        printf "[%s] %s\n" "$(date)" "state file not found. initilising empty file array"
        declare -gA stat1
    fi
}

# startup
startup () {
    read_state
    dirs_str=$(printf '%s\\n' "${dirs[@]}")

    printf '[%s] %s\n%b\n' "$(date)" 'startup' "$dirs_str"
    alert startup

    report=FALSE
    count=0
}

# monitor directories
monitord () {
    # initialise
    startup
    printf "[%s] %s\n\n" "$(date)" "monitor deamon running"

    # monitor
    while true; do  
        printf "\n[%s] %s %s\n" "$(date)" "monitor cycle:" "$count"
        count=$((count + 1))
        t_short=$(date +"%Y%m%d")

        # check RDS connection
        connection_test

        if [[ "$connection" == "ACTIVE" ]]; then

            # generate chsum & record file status
            for dir in "${dirs[@]}"; do
                status=$(find "$dir" -not -path "*/.*" -type f -exec stat {} \;)
                stat2[$dir]=$status
                chsum2[$dir]=$(echo "$status" | grep File | sed "s/ //g")
            done

            # check for changes
            if [[ ${chsum1[*]} != "${chsum2[*]}" ]]; then
                if [[ ${#chsum1[@]} != 0 ]]; then
                    printf "[%s] %s\n" "$(date)" "change detected"
                    check
                fi
            else
                printf "[%s] %s\n" "$(date)" "no change detected"
            fi

            # update state
            rearray chsum2 chsum1
            rearray stat2 stat1
            write_state

            # copy output if specified
            if [[ $copy_dir != "" ]]; then
                cp -ru reports "$copy_dir"
                cp -ru latest "$copy_dir"
                cp -ru log "$copy_dir"
            fi

        else
            printf "[%s] %s\n" "$(date)" "skipping check cycle until connection is restored"
        fi

        sleep $check_interval
    done
}

# generate ssmtp config
generate_ssmtp_config () {
    printf "%s\n" \
    "root=$email_source"  \
    "mailhub=$mailhub" \
    "rewriteDomain=$rewriteDomain" \
    "hostname=$hostname" \
    "FromLineOverride=YES" \
    > /etc/ssmtp/ssmtp.conf
}

# check parameters
parameter_check () {
    # check required parameters are present in conf/monitor.conf
    if [[ -z "$email_recipients" || -z "$email_source" || -z "$monitor_file" || -z "$handshake_dir" || -z "$check_interval" || -z "$periodic_check" ]]; then
        printf "[%s] %s\n" "$(date)" "Missing required parameters in conf/monitor.conf. Check README. Exiting."
        exit 1
    fi
}


#### main ####

# set up logging
mkdir -p log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>log/monitor.log 2>&1

# check config exists and read config
if [ ! -f conf/monitor.conf ]; then
    printf "[%s] %s\n" "$(date)" "Configuration file not found. Exiting."
    exit 1
fi
source conf/monitor.conf

# create directories
mkdir -p reports
mkdir -p latest
mkdir "$copy_dir"

# check parameters
parameter_check

#generate_ssmtp_config
generate_ssmtp_config

# start monitoring
monitord
