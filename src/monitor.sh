#!/bin/bash

alert () {
    # need to setup mail server and email
    #(date +"%Y%m%d"
    cat latest/latest_summary.txt >&2
    cat latest/latest_report.txt >&2
}

generate_report() {
    # get info of deletions
    info_arr=()
    for file in $removed; do
        sub_info=$(echo "${stat1[$j]}" | grep "$file" -A 7)
        info_arr+=("$sub_info\n")
    done

    n_missing=$(echo "$removed" | wc -l)
    header=$(echo "##### ----- ${dirs[$j]} ----- #####\nReport generated: $t_long\nMissing files: $n_missing")
    content=$(echo "${info_arr[@]}")
    printf "\n\n\n$header\n\n$content"
}

check () {
    # identify deletions
    reports=()
    summaries=()
    t_short=$(date +"%Y%m%d")
    t_long=$(date)


    for j in ${!chsum1[@]}; do
        change=$(diff <(echo "${chsum1[$j]}") <(echo "${chsum2[$j]}"))
        removed=$(echo "$change" | grep "<" | sed "s/<.*File: //g")

        if [[ "$removed" != "" ]]; then
            reports[$j]=$(generate_report)
            summaries[$j]=$(echo "\n$removed")
            report=TRUE
        fi
    done

    if [[ "$report" == "TRUE" ]]; then
        full_summary=${summaries[@]}
        full_report=${reports[@]}
        
        mkdir -p reports/$t_short
        n_files=$(ls reports/$t_short | wc -l)
        report_loc=reports/$t_short/report_$n_files.txt
        summary_loc=reports/$t_short/summary_$n_files.txt

        printf "Data loss summary - $t_long" > $summary_loc
        printf "$full_summary" >> $summary_loc
        printf "Data loss report - $t_long" > $report_loc
        printf "$full_report" >> $report_loc

        cat $summary_loc > latest/latest_summary.txt
        cat $report_loc > latest/latest_report.txt

        alert
        report=FALSE
    fi
}

monitord () {
    stat1=()
    chsum1=()
    report=FALSE

    while [[ true ]]; do  
        chsum2=()
        # generate chsum & record file status
        for i in "${!dirs[@]}"; do
            dir=${dirs[$i]}

            status=$(find $dir -not -path "*/.*" -type f -exec stat {} \;)
            chsum2[$i]=$(echo "$status" | grep File)
            stat2[$i]=$status
        done

        # check chsums
        if [[ ${chsum1[@]} != ${chsum2[@]} ]]; then
            if [ -n "$chsum1" ]; then
                check # run checks and alert if required
            fi
            chsum1=("${chsum2[@]}")
            stat1=("${stat2[@]}")
        fi

        sleep 2
    done
}

readarray -t dirs < directories.txt
mkdir -p reports
mkdir -p latest
monitord

# Set up email reporting (sendmail)
# Dockerise