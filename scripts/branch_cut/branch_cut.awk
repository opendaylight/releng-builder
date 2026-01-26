#!/usr/bin/awk -f
# SPDX-License-Identifier: EPL-1.0
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
    new_tag                     = new_reltag       # new release tag
    curr_tag                    = curr_reltag      # current release tag
    prev_tag                    = prev_reltag      # previous release tag
    eol_tag                     = eol_reltag       # EOL release tag

    new_release                 = tolower(new_tag)
    curr_release                = tolower(curr_tag)
    prev_release                = tolower(prev_tag)
    eol_release                 = tolower(eol_tag)

    # EOL-only mode: only eol_release is set
    eol_only_mode = (length(eol_release) > 0 && length(new_release) == 0 && length(curr_release) == 0)

    ws = "[\\t ]*"                                 # white-spaces
    startpat = "^" ws "- project:"                 # start pattern
    endpat = startpat                              # end pattern
    op = "^" ws "---" ws "$"                       # match files starts with "---"

    next_release_tag            = "^" ws "next-release-tag: '{stream}'"
    master                      = "'master'"
    new_branch                  = "'stable/" new_release "'"
    curr_branch                 = "'stable/" curr_release "'"
    prev_branch                 = "'stable/" prev_release "'"
    eol_branch                  = "'stable/" eol_release "'"

    # replace block to add new release
    new_rel_yaml_tag            = "- " new_release ":";
    br_master_yaml_tag          = "    branch: 'master'";
    jre_yaml_tag                = "    jre: 'openjdk21'";
    java_version_yaml_tag       = "    java-version: 'openjdk21'";
    curr_rel_yaml_tag           = "- " curr_release ":";
    br_stable_curr_yaml_tag     = "    branch: 'stable/" curr_release "'";

    # replace block for autorelease-projects
    #new_rel_yaml_tag           = "- " new_release ":";
    next_rel_tag_new_yaml_tag   = "    next-release-tag: '{stream}'";
    #br_master_yaml_tag         = "    branch: 'master'";
    jdk_yaml_tag                = "    jdk: 'openjdk8'";
    intg_test_yaml_tag          = "    integration-test: " new_release;
    extra_mvn_opts_tag          = "    extra-mvn-opts: -Dsft.heap.max=4g"
    #curr_rel_yaml_tag          = "- " curr_release ":";
    next_rel_tag_curr_yaml_tag  = "    next-release-tag: '{stream}'";
    #br_stable_curr_yaml_tag    = "    branch: 'stable/" curr_release "'";

    # search patterns
    smaster = "^" ws "- master:"
    sstream = "^" ws "stream:"
    srelease = "^" ws "- " curr_release ":"
    seol_release = "^" ws "- " eol_release ":"
    snext_release_tag = "^" ws "next-release-tag:"
    #if (l ~ next_release_tag) { next_release_tag = 1; continue; }
    sbranch = "^" ws "branch: " master
    sfunctionality = "^" ws "functionality:"

    debug = 0                                   # set to 1 to print debug info
    file_format = 2                             # project stream format

    release_found = 0
    stream_found = 0
    nrt_found = 0
    func_found = 0
    eol_found = 0
    skip_until_next_release = 0
}

{
    # exit if release info is not available (unless EOL-only mode)
    if (!eol_only_mode && (length(new_release) == 0 || length(curr_release) == 0)) {
        exit;
    }
    
    # In EOL-only mode, must have eol_release
    if (eol_only_mode && length(eol_release) == 0) {
        exit;
    }

    # read all lines of the file into an array
    file[NR] = $0
}

END {
    n = NR                                      # total number of lines
    
    # EOL-only mode: simple line-by-line processing
    if (eol_only_mode) {
        process_eol_only()
        if (debug) {
            print "EOL-only mode: processed " n " lines" > "/dev/stderr"
        }
        exit
    }
    
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

function process_eol_only(   i, l, in_eol_block, eol_indent, line_indent, stream_indent) {
    in_eol_block = 0
    eol_indent = 0
    stream_indent = -1
    
    for (i = 1; i <= n; i++) {
        l = file[i]
        
        # Track the indent level of "stream:" to know where releases are
        if (l ~ /^[[:space:]]*stream:[[:space:]]*$/) {
            match(l, /^[[:space:]]*/)
            stream_indent = RLENGTH
            print l
            continue
        }
        
        # Detect start of EOL release block
        if (l ~ seol_release) {
            in_eol_block = 1
            # Calculate indent level (number of leading spaces)
            match(l, /^[[:space:]]*/)
            eol_indent = RLENGTH
            if (debug) print "Found EOL block '" eol_release "' at line " i ", indent=" eol_indent > "/dev/stderr"
            continue  # Skip the release line itself
        }
        
        # If in EOL block, check if we should stop skipping
        if (in_eol_block) {
            # Blank lines: keep them
            if (l ~ /^[[:space:]]*$/) {
                print l
                continue
            }
            
            # Calculate current line indent
            match(l, /^[[:space:]]*/)
            line_indent = RLENGTH
            
            # If we hit a key at same/lower indent than stream section, stop skipping
            if (stream_indent >= 0 && line_indent <= stream_indent) {
                in_eol_block = 0
                print l
                if (debug) print "End of EOL block at line " i " (lower/same indent as stream)" > "/dev/stderr"
                continue
            }
            
            # If we hit another release entry at same indent, stop skipping  
            if (l ~ /^[[:space:]]*- [a-z]+:[[:space:]]*$/ && line_indent == eol_indent) {
                in_eol_block = 0
                print l
                if (debug) print "End of EOL block at line " i " (new release)" > "/dev/stderr"
                continue
            }
            
            # Still in EOL block, skip this line
            if (debug) print "Skipping line " i ": " substr(l, 1, 60) > "/dev/stderr"
            continue
        }
        
        # Not in EOL block, keep the line
        print l
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

function process_blk(bs, be, bn,   i, l, eol_indent, in_eol_block) {
    if (debug) {
        print "process_blk: bn=" bn ", bs=" bs " ,be=" be " eol_only_mode=" eol_only_mode
    }

    # EOL-only mode: just remove EOL blocks
    if (eol_only_mode) {
        in_eol_block = 0
        eol_indent = 0
        
        for (i = bs + 1; i <= be ; i++) {
            l = file[i]
            
            # Detect start of EOL release block
            if (l ~ seol_release) {
                in_eol_block = 1
                # Calculate indent level of the EOL release line
                eol_indent = match(l, /[^ ]/) - 1
                if (debug) print "Found EOL block at line " i ", indent=" eol_indent
                continue  # Skip this line
            }
            
            # If in EOL block, skip lines until we hit the next release or same/lower indent level
            if (in_eol_block) {
                # Check if this is a new release entry at same indent level
                if (l ~ /^[[:space:]]*- [a-z]+:/ && match(l, /[^ ]/) - 1 == eol_indent) {
                    # Found next release, stop skipping
                    in_eol_block = 0
                    newblk[++nex3] = l
                    if (debug) print "End of EOL block at line " i
                    continue
                }
                # Check if we hit a blank line or lower indent (end of stream section)
                if (l ~ /^[[:space:]]*$/ || (l ~ /^[[:space:]]*[^ ]/ && match(l, /[^ ]/) - 1 < eol_indent)) {
                    # End of EOL block
                    in_eol_block = 0
                    newblk[++nex3] = l
                    if (debug) print "End of EOL block (blank/lower indent) at line " i
                    continue
                }
                # Skip all lines in the EOL block
                if (debug) print "Skipping EOL line " i ": " l
                continue
            }
            
            # Not in EOL block, keep the line
            newblk[++nex3] = l
        }
        return
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
            if (l ~ /branch:/) sub(master, "'master'", l)
            newblk[++nex1] = l
        }
        # re-create old block and change master to stable/branch
        for (i = 1; i <= length(firstblk)-1; i++) {
            l = firstblk[i]
            if (l ~ /branch:/) sub(/"master"|'master'/, curr_branch, l)
            oldmaster[++nex2] = l
        }
    } else if (file_format == 0) {
        # Handle multi-stream format
        in_eol_block = 0
        eol_indent = 0
        
        for (i = 1; i <= length(firstblk)-1; i++) {
            l = firstblk[i]
            if (l ~ sstream) { stream_found = 1; }
            
            # Skip EOL release block
            if (l ~ seol_release && length(eol_release) > 0) {
                in_eol_block = 1
                eol_indent = match(l, /[^ ]/) - 1
                stream_found = 0
                continue
            }
            
            # If in EOL block, skip until next release
            if (in_eol_block) {
                if (l ~ /^[[:space:]]*- [a-z]+:/ && match(l, /[^ ]/) - 1 == eol_indent) {
                    in_eol_block = 0
                    # Fall through to process this line
                } else if (l ~ /^[[:space:]]*$/ || (l ~ /^[[:space:]]*[^ ]/ && match(l, /[^ ]/) - 1 < eol_indent)) {
                    in_eol_block = 0
                    newblk[++nex3] = l
                    continue
                } else {
                    continue
                }
            }
            
            if (l ~ srelease) {
                # Found current release (e.g., "- vanadium:")
                release_found = 1;
                indent = substr(l, 1, index(l, "-")-1);

                # Insert NEW release block BEFORE current release
                if (stream_found && !nrt_found) {
                    newblk[++nex3] = indent new_rel_yaml_tag;
                    newblk[++nex3] = indent "    " "branch: 'master'";
                    newblk[++nex3] = indent curr_rel_yaml_tag;
                    newblk[++nex3] = indent "    " "branch: 'stable/" curr_release "'";
                }
                if (stream_found && nrt_found) {
                    newblk[++nex3] = indent new_rel_yaml_tag;
                    newblk[++nex3] = indent next_rel_tag_new_yaml_tag;
                    newblk[++nex3] = indent "    " "branch: 'master'";
                    newblk[++nex3] = indent intg_test_yaml_tag;
                    newblk[++nex3] = indent extra_mvn_opts_tag;
                    newblk[++nex3] = indent curr_rel_yaml_tag;
                    newblk[++nex3] = indent next_rel_tag_curr_yaml_tag;
                    newblk[++nex3] = indent "    " "branch: 'stable/" curr_release "'";
                }

                # Skip the next line (the old branch line for current release)
                i++;

                stream_found = 0;
                release_found = 0;
                nrt_found = 0;
                continue;  # Skip the old current release line (we already added updated version)
            }
            if (l ~ sfunctionality) { func_found = 1; }
            if (l ~ snext_release_tag) { nrt_found = 1; }

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
