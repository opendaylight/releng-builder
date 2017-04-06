#!/usr/bin/awk -f

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
##############################################################################

BEGIN {
    new_tag                     = ""            # new release tag
    curr_tag                    = ""            # current release tag
    prev_tag                    = "Boron"       # previous release tag

    new_release                 = tolower(new_tag)
    curr_release                = tolower(curr_tag)
    prev_release                = tolower(prev_tag)

    ws = "[\\t ]*"                              # white-spaces
    startpat = "^" ws "- project:"              # start pattern
    endpat = startpat                           # end pattern
    op = "^" ws "---" ws "$"                    # match files starts with "---"

    next_release_tag            = "^" ws "next-release-tag: " curr_tag
    master                      = "'master'"
    new_branch                  = "'stable/" new_release "'"
    curr_branch                 = "'stable/" curr_release "'"
    prev_branch                 = "'stable/" prev_release "'"

    # replace block to add new release
    new_rel_yaml_tag            = "- " new_release ":";
    br_master_yaml_tag          = "    branch: 'master'";
    jre_yaml_tag                = "    jre: 'openjdk8'";
    curr_rel_yaml_tag           = "- " curr_release ":";
    br_stable_curr_yaml_tag     = "    branch: 'stable/" curr_release "'";

    # replace block for autorelease-projects
    #new_rel_yaml_tag           = "- " new_release ":";
    next_rel_tag_new_yaml_tag   = "    next-release-tag: " new_tag;
    #br_master_yaml_tag         = "    branch: 'master'";
    jdk_yaml_tag                = "    jdk: 'openjdk8'";
    intg_test_yaml_tag          = "    integration-test: " new_release;
    #curr_rel_yaml_tag          = "- " curr_release ":";
    next_rel_tag_curr_yaml_tag  = "    next-release-tag: " curr_tag;
    #br_stable_curr_yaml_tag    = "    branch: 'stable/" curr_release "'";

    # search patterns
    smaster = "^" ws "- master:"
    sstream = "^" ws "stream:"
    srelease = "^" ws "- " curr_release ":"
    #if (l ~ next_release_tag) { next_release_tag = 1; continue; }
    sbranch = "^" ws "branch: " master

    debug = 0                                   # set to 1 to print debug info
    file_format = 2                             # project stream format

    release_found = 0
    stream_found = 0
    nrt_found = 0
}

{
    # exit if release info is not available
    if ((length(new_release) == 0 || length(curr_release) == 0)) {
        exit;
    }

    # read all lines of the file into an array
    file[NR] = $0
}

END {
    n = NR                                      # total number of lines
    find_blks()                                 # gets number of blocks between start/end pattern
    process_blk(arr_bs[1], arr_be[1], 1)        # pass start and end of each block and process first block
    update_file(arr_be[1])                      # write processed content

    if (debug) {
        print "number of blocks="nb;
        print "total records in file[]="length(f);
        print "size of firstblk[]="length(firstblk);
        print "size of newblk[]="length(newblk);
        print "size of oldmaster[]="length(oldmaster);
        print "size of newblk[]="length(newblk);
    }
}

function find_blks(   i, l, bs, be) {
    for (i = 1; i <= n; i++) {
        l = file[i]
        if (l ~ startpat) project = 1                        # start pattern
        if (bs > be && l ~ endpat) arr_be[++be] = i - 1      # block end
        if (           l ~ startpat) arr_bs[++bs] = i - 1    # block start
    }
    nb = be

    # to handle files with single blocks
    if (nb == 0 && length(file) > 1 && project == 1) {
        nb = 1
        arr_bs[1] = 1                               # start after line '---'
        arr_be[1] = length(file)                    # set length of the file
    }

    if (debug) {
        for (i = 1; i < nb; i++)
            print "find_blks: nb=" nb " arr_bs[" i "]="arr_bs[i]" arr_be[" i "]="arr_be[i];
    }
}

function process_blk(bs, be, bn,   i, l) {
    if (debug) {
        print "process_blk: bn=" bn ", bs=" bs " ,be=" be
    }

    # get the first block
    for (i = bs + 1; i <= be ; i++) {
        l = file[i]
        # determine file format
        if (l ~ /stream:/) {
            x=index(l,":")
            s = substr(l, x+2, length(l) - x)
            if (s == curr_release || s == new_release) {
                file_format = 1
            } else if (length(s) == 0 ) {
                file_format = 0
            }
        }
        firstblk[++nex] = l
    }

    if (debug) {
        print "process_blk: stream='" s "' length(s)=" length(s)" file_format='" file_format "'"
    }

    # Handle single stream format
    if (file_format == 1) {
        # create new block to be inserted
        for (i = 1; i <= length(firstblk); i++) {
            l = firstblk[i]
            if (l ~ /name:|stream:/) sub(curr_release, new_release, l)
            newblk[++nex1] = l
        }
        # re-create old block and change master to stable/branch
        for (i = 1; i <= length(firstblk)-1; i++) {
            l = firstblk[i]
            if (l ~ /branch:/) sub(master, curr_branch, l)
            oldmaster[++nex2] = l
        }
    } else if (file_format == 0) {
        # Handle multi-stream format
        for (i = 1; i <= length(firstblk)-1; i++) {
            l = firstblk[i]
            if (l ~ sstream) { stream_found = 1; }
            if (l ~ srelease) { release_found = 1; indent = substr(l, 1, index(l, "-")-1); continue; }
            if (l ~ next_release_tag) { nrt_found = 1; continue; }
            if (l ~ sbranch) {
                # append lines
                if (stream_found && release_found && !nrt_found) {
                    newblk[++nex3] = indent new_rel_yaml_tag;
                    newblk[++nex3] = indent br_master_yaml_tag;
                    newblk[++nex3] = indent jre_yaml_tag;
                    newblk[++nex3] = indent curr_rel_yaml_tag;
                    newblk[++nex3] = indent br_stable_curr_yaml_tag;
                    stream_found = 0; release_found = 0;
                    continue;
                }
                if (stream_found && release_found && nrt_found) {
                    newblk[++nex3] = indent new_rel_yaml_tag;
                    newblk[++nex3] = indent next_rel_tag_new_yaml_tag;
                    newblk[++nex3] = indent br_master_yaml_tag;
                    newblk[++nex3] = indent jdk_yaml_tag;
                    newblk[++nex3] = indent intg_test_yaml_tag;
                    newblk[++nex3] = indent curr_rel_yaml_tag;
                    newblk[++nex3] = indent next_rel_tag_curr_yaml_tag;
                    newblk[++nex3] = indent br_stable_curr_yaml_tag;
                    stream_found = 0; release_found = 0; nrt_found=0;
                    continue;
                }
            }
            newblk[++nex3] = l

            if (debug) {
                print "process_blk: append(newblk[]) : stream="stream" release_found="release_found
            }
        }
    } else {
        # exit on unknown file format
        exit;
    }
}

function update_file(be,   i, j, l) {
    i = 1
    # handle lines before "---"
    while (i <= n) {
        print l = file[i++]
        if (l ~ op) break
    }

    if (debug) {
        print "writing master block"
    }

    # Handle single stream format
    if (file_format == 1) {
        for (j = 1; j <= nex1; j++)                   # write new branch block
            print newblk[j]

        if (debug) {
            print "writing stable block"
        }

        for (j = 1; j <= nex2; j++)                   # write updated branch block
            print oldmaster[j]

    # Handle multi-stream format
    } else if (file_format == 0) {
        # print the first block
        for (j = 1; j <= nex3; j++)                   # write multi-stream block
            print newblk[j]
    }

    if (debug) {
        print "writing rest of the file"
    }

    while (be <= n) {                                 # write rest of the file
        print file[be++]
    }
}
