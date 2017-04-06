#!/usr/bin/awk -f

/stream:/ { s = 1; }
/- carbon:/ { c = 1; indent = substr($0, 1, index($0, "-")-1); next; }
$1 == "branch:" && $2 == "'master'" {
    if (s && c) {
        print indent "- nitrogen:";
        print indent "    branch: 'master'";
        print indent "    jre: 'openjdk8'";
        print indent "- carbon:";
        print indent "    branch: 'stable/carbon'";
        s = 0; c = 0;
    }
    next;
}
{ print }
