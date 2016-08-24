#!/bin/bash

# Pre-defined Values
table="scripts_perf_results"
cols='"job_name", "build_number", "title", "yaxis", "min_value", "max_value", "avg_value", "plot_group"'
job_name=$JOB_NAME
build_number=$BUILD_NUMBER

# Password for remote database
export PGPASSWORD=odl

# First Plot Data
title1="{01-plot-title}"
yaxis1="{01-plot-yaxis}"
plot_group1="{01-plot-group}"
file_name1="{01-plot-data-file}"

# Second Plot Data
title2="{02-plot-title}"
yaxis2="{02-plot-yaxis}"
plot_group2="{02-plot-group}"
file_name2="{02-plot-data-file}"

# Script to parse csv files and insertion into database
for i in 1 2
do
    filename=file_name$i
    eval file=\$$filename
    INPUT=$file
    OLDIFS=$IFS
    IFS=,
    check=1
    while read min max avg
    do
        if [ $check -eq 1 ]
        then
            check=$((check+1))
            continue
        fi
        max_value=$max
        min_value=$min
        avg_value=$avg
        title=title$i
        eval title=\$$title
        yaxis=yaxis$i
        eval yaxis=\$$yaxis
        plot_group=plot_group$i
        eval plot_group=\$$plot_group
        insertsql="insert into $table ($cols) VALUES('$job_name','$build_number','$title','$yaxis','$min_value','$max_value','$avg_value','$plot_group');"
        psql -U odluser -d dashboard -h 139.59.8.253 -c "$insertsql"
    done < $INPUT
    IFS=$OLDIFS
done
