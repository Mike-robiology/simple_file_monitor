#!/bin/bash

# This script monitors specified directories for file deletions and sends email alerts if any deletions are detected.
# It also performs periodic connection tests and sends alerts if the connection is inactive.

# Functions:
# - rearray: Copies an associative array.
# - email: Sends an email using a specified template.
# - alert: Triggers an email alert based on the type of alert (connection or data loss).
# - generate_report: Generates a report of deleted files.
# - check: Identifies deletions and generates reports and summaries.
# - connection_test: Checks the connection status and sends an alert if inactive.
# - write_state: Writes the current state of the monitored directoried to a file.
# - read_state: Loads monitored directories and previous state from a file.
# - monitord: Directory monitor deamon, runs the monitoring process.

# Main:
# - Reads configuration from conf/monitor.config.
# - Creates necessary directories.
# - Starts the monitoring process.

# copy associative array
rearray () {
    tmp=$(declare -p "$1")
    tmp=${tmp/-A/-Ag}
    eval "${tmp/$1/$2}"
}

# send email
email () {
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
    #cat latest/email.txt >&2
}

# send email alert
alert () {
    if [[ $1 == "connection" ]]; then
        subject="$connection_test_subject"
        body="----- Start of message ----- \n\n$connection_test_body$connection \n\n----- End of message -----"
    elif [[ $1 == "startup" ]]; then
        subject="$startup_subject"
        body="----- Start of message ----- \n\n$startup_body \n\nFiles being monitored: \n$dirs_str \n\n----- End of message -----"
    else
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

    n_missing=$(echo "$removed" | wc -l)
    header=$(echo -e "##### ----- $dir ----- #####\nMissing files: $n_missing")
    content=$(echo -e "${info_arr[*]}")
    printf "\n%s\n---\n%s" "$header" "$content" 
}

# identify deletions
check () {
    reports=()
    summaries=()

    len=${#chsum1[@]}
    for i in $(seq 0 $((len - 1))); do
        dir=${dirs[$i]}
        change=$(diff -Bw <(echo "${chsum1[$dir]}") <(echo "${chsum2[$dir]}"))
        removed=$(echo "$change" | grep "< File:" | sed "s/< File://g")

        if [[ "$removed" != "" ]]; then
            reports[i]=$(generate_report)
            summaries[i]=$(echo -e "$removed")
            report=TRUE
        fi
    done

    if [[ "$report" == "TRUE" ]]; then
        mkdir -p reports/"$t_short"
        n_files=$(find reports/"$t_short"/report* -type f | wc -l)
        report_loc=reports/$t_short/report_$n_files.txt
        summary_loc=reports/$t_short/summary_$n_files.txt

        printf "Data loss summary - %s\n" "$t_long" > "$summary_loc"
        printf "\n%s\n" "${summaries[@]}" >> "$summary_loc"
        printf "Data loss report - %s" "$t_long" > "$report_loc"
        printf "\n%s\n" "${reports[@]}" >> "$report_loc"


        cat "$summary_loc" > latest/summary.txt
        cat "$report_loc" > latest/report.txt

        alert
        report=FALSE
    fi
}

# handshake alert
connection_test () {
    if [ ! -d $handshake_dir ]; then
        connection="INACTIVE"
        alert connection
    else
        connection="ACTIVE"
        if [[ "$((count % $periodic_check))" == 0 ]]; then
            alert connection
        fi
    fi
}

# write state to file
write_state () {
    tmp=$(declare -p stat1)
    tmp=${tmp/-A/-Ag}
    echo "$tmp" > latest/state_file.txt

}

# load monitored directories and previous state
read_state () {
    readarray -t dirs < conf/directories.txt
    declare -gA stat2
    declare -gA chsum1
    declare -gA chsum2

    if [ -f latest/state_file.txt ]; then
        source latest/state_file.txt # load stat1
        for dir in "${dirs[@]}"; do
            status=${stat1[$dir]}
            chsum1[$dir]=$(echo "$status" | grep File | sed "s/ //g")
        done   
    else
        declare -gA stat1
    fi
}

# startup
startup () {
    read_state
    dirs_str=$(printf '%s\\n' "${dirs[@]}")
    alert startup
    report=FALSE
    count=0
}

# monitor directories
monitord () {
    # initialise
    startup

    # monitor
    while true; do  
        count=$((count + 1))
        t_short=$(date +"%Y%m%d")
        t_long=$(date)

        # check RDS connection
        connection_test

        # generate chsum & record file status
        for dir in "${dirs[@]}"; do
            status=$(find "$dir" -not -path "*/.*" -type f -exec stat {} \;)
            stat2[$dir]=$status
            chsum2[$dir]=$(echo "$status" | grep File | sed "s/ //g")
        done

        if [[ ${chsum1[*]} != "${chsum2[*]}" ]]; then
            if [[ ${#chsum1[@]} != 0 ]]; then
                check
            fi
        fi

        # copy reports if specified
        if [[ $copy_dir != "" ]]; then
            cp -ru reports "$copy_dir"
            cp -ru latest "$copy_dir"
        fi

        # update state
        rearray chsum2 chsum1
        rearray stat2 stat1
        write_state

        sleep $check_interval
    done
}


#### main ####

# read config
source conf/monitor.conf

# create directories
mkdir -p reports
mkdir -p latest
mkdir -p "$copy_dir"

# start monitoring
monitord

# TO DO
# final test
# Dockerise
# add docker secrets to github repository
# email if docker container is not running/cannot restart