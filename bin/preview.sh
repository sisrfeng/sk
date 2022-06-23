#!/usr/bin/env bash

reverse="\x1b[7m"
reset="\x1b[m"

if [ -z "$1" ]; then
    echo "usage: $0 filename[:lineno][:ignored]"
    exit 1
fi

ifs=':' read -r -a input <<< "$1"
file=${input[0]}
center=${input[1]}

if [[ $1 =~ ^[a-z]:\\ ]]; then
    file=$file:${input[1]}
    center=${input[2]}
fi

if [[ -n "$center" && ! "$center" =~ ^[0-9] ]]; then
    exit 1
fi
center=${center/[^0-9]*/}

file="${file/#\~\//$home/}"
if [ ! -r "$file" ]; then
    echo "file not found ${file}"
    exit 1
fi

file_length=${#file}
mime=$(file --dereference --mime "$file")
if [[ "${mime:file_length}" =~ binary ]]; then
    echo "$mime"
    exit 0
fi

if [ -z "$center" ]; then
    center=0
fi

if [ -z "$sk_preview_command" ] && command -v bat > /dev/null; then
    bat --style="${bat_style:-numbers}" --color=always --pager=never \
            --highlight-line=$center "$file"
    exit $?
fi

default_command="highlight -o ansi -l {} || coderay {} || rougify {} || cat {}"
cmd=${sk_preview_command:-$default_command}
cmd=${cmd//{\}/$(printf %q "$file")}

eval "$cmd" 2> /dev/null | awk "{ \
        if (nr == $center) \
                { gsub(/\x1b[[0-9;]*m/, \"&$reverse\"); printf(\"$reverse%s\n$reset\", \$0); } \
        else printf(\"$reset%s\n\", \$0); \
        }"
