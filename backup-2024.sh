#!/bin/bash
# Project Name : Backup Manager 2024


##
## WARNING: the script is not meant to be used for multilines file/directory name
##


##
## WARNING: try to use empty destination directory if you used default mode
##

##
## The script will offer 3 modes in the next update :
##
##
##   I- Check all (Default): checks all other ".tar.gz" files content in the destination directory, and delete
## files that it's content is same as new backup content, or subset of the new file 
## content, the content is checked using (tar tf) command
##
##  II- Delete all: deletes all other ".tar.gz" files in the destination directory  
##
## III- Keep all: keeps all other ".tar.gz" files in the destination directory  
##


error_flag=0
default_error_code=1

err(){
    # err [message] <type> <isexit> <exit/return code>
    #
    #   I- message (mandatory): text to print
    #
    #  II- type (optional "default is (1/note)"): 
    #      1 : note (Default)
    #      2 : warning
    #      3 : error: the text is printed into stderr, and it needs two more arguments
    #
    #
    # III- isexit (optional "default is 1"):
    #      0 : exit after printing 
    #          (set exit code in the next
    #           arg, default error code
    #           is used if error code
    #           is not set).
    #      1 : return a status code after printing 
    #          (set return code in the next
    #           arg, default return code
    #           is used if return code
    #           is not set).
    #      2 : do not exit or return
    #
    #  IV- error/return code : 
    #      to set error/return code, must be numeric, 
    #      if not numeric or not set, the default 
    #      value will be used. 
    
    local text="$1"
    local type=${2-1}
    local isexit=${3-1}
    local error_code=${4-$default_error_code}
    local typestr=""
    local fd=1
    
    if ! [[ "$type" =~ ^[0-9]+$ ]]; then
        type=1
    fi

    if ! [[ "$isexit" =~ ^[0-9]+$ ]]; then
        isexit=1
    fi

    if ! [[ "$error_code" =~ ^[0-9]+$ ]]; then
        error_code=$default_error_code
    fi
    case $type in 
    1)
        typestr="NOTE"
        fd=1 #stdout
    ;;
    2)
        typestr="WARNING"
        fd=1 #stdout
    ;; 
    3)
        typestr="ERROR"
        fd=2 #stderr
    ;;
    *)
        typestr="NOTE"
        fd=1 #stdout
    ;;
    esac
    
    if [ $error_flag -eq 0 ]; then 
        >&$fd echo -e "[$typestr:START]\n$text\n[$typestr:END]"
        if [ "$isexit" -eq 0 ]; then
            exit "$error_code"
        elif [ "$isexit" -eq 1 ]; then
            return "$error_code"
        fi

    fi
    
}



abs_path_list=()
ends_list=()
list=()

compare_arrays() { 
    
    # Takes two arrays as arguments
    # Returns 0 if two arrays are equal
    # Returns 1 if array2 is a subset of array1
    # Returns 2 if array1 is a subset of array2
    # Returns 3 if arrays are not a subset of each other
    # the function DOES NOT require the arrays elements to be sorted or unique 


    ##
    ##  # Time complexity : O(2*n + 2*m), where n is array1's length, m is array2's length
    ##                      ^^^^^^^^^^^^
    ##               simplified to O(n+m)
    
    if [ "$#" -ne 2 ]; then
        err "Invalid argument number to compare_arrays() function!" 3 1 10; return $?
    fi

    declare -A hash_table1 #associative list
    declare -A hash_table2 #associative list

    local array1=("${!1}") 
    local array2=("${!2}")  
    for element in "${array1[@]}"; do
        if [ ! -z "$element" ] ; then
            hash_table1["$element"]=1 
        fi
    done
    for element in "${array2[@]}"; do
        if [ ! -z "$element" ] ; then
            hash_table2["$element"]=1 
        fi
    done

    local fsubs=true
    local ssubf=true

    for element in "${array2[@]}"; do 
        if [ ! -z "$element" ] ; then
            if [ -z "${hash_table1[$element]}" ]; then 
                ssubf=false
                break
            fi
        fi
    done

    for element in "${array1[@]}"; do
        if [ ! -z "$element" ] ; then
            if [ -z "${hash_table2[$element]}" ]; then 
                fsubs=false
                break
            fi
        fi
    done

    if [ "$fsubs" = true ] && [ "$ssubf" = true ]; then
        return 0 # first equals the second
    elif [ "$fsubs" = false ] && [ "$ssubf" = true ]; then
        return 1 # second is a subset of first
    elif [ "$fsubs" = true ] && [ "$ssubf" = false ]; then
        return 2 # first is a subset of second
    elif [ "$fsubs" = false ] && [ "$ssubf" = false ]; then
        return 3 # first and second are not equal or subset
    else
        return 4
    fi
}

convert_to_array() {
    # Converts strings to array, elements are separated by separator
    # Stores the output in the global array $list
    # Returns 0 if no errors occurred
    # $1 is the string, $2 is the separator
    # example : convert_to_array "AAA-BBSAAF-A-S" "-"
    # result : list=("AAA" "BBSAAF" "A" "S") 
    
    local input="$1"
    local separator="$2"
    list=()
    
    local record_count=$(echo "$input" | awk -v sep="$separator" 'BEGIN{RS=sep}END{print NR}'  )
    local element=""
    for ((i = 1; i <= record_count; i++)); do
        element="$(echo "$input" | awk -v sep="$separator" -v i="$i" 'BEGIN{RS=sep} NR == i {print $0}')"
        if [ -z "$element" ]; then
            break
        fi
        list+=( "$element" )
    done
    return 0
}



convert_to_arrayln() {
    # Converts strings to array, each element is a line 
    # Stores the output in the global array $list
    # Returns 0 if no errors occurred
    # $1 is the string

    local input="$1"
    convert_to_array "$input" "\n" || return $?    
    return 0
}



remove_forward_slash(){
    # takes list and remove leading forward slash (/) (fs) from all the elements
    
    if [ "$#" -ne 1 ]; then
        err "Invalid argument number to remove_forward_slash() function!" 3 1 8 ; return $?
    fi
    local array=("${!1}")
    list=()
    for i in "${array[@]}";do
        list+=( "${i#/}" )
    done
}

append_forward_slash(){
    # takes list and append forward slash (/) (fs), to elements that are valid directory
    
    if [ "$#" -ne 1 ]; then
        err "Invalid argument number to append_forward_slash() function!" 3 1 9 ; return $?
    fi
    local array=("${!1}")
    list=()
    for i in "${array[@]}";do
        local d="${i#/}" 
        local d="/$d"
        if [ -d "$d" ]; then
            list+=( "${i%/}/" )
        else
            list+=( "${i%/}" )
        fi
    done
}





show_help(){
    echo "Usage: $0 <directories/files to backup (seperate by space)> -d <backup destination directory> "
}


get_time(){
    /usr/bin/env date +%d-%m-%Y-%H-%M
}

add_to_list(){
    if [ "$#" -lt 1 ]; then
        err "Few arguments to add_to_list() function." 3 1 1; return $?
    elif [ "$#" -gt 1 ]; then
        err "Many arguments to add_to_list() function." 3 1 2; return $?
    fi

    if [ -z "$1" ]; then
        return 3
    elif [ -d "$1" ] || [ -e "$1" ] ; then 
        abs_path=`realpath "$1"`
        abs_path_list+=("$abs_path")
        abs_path_list_dq+=("\"$abs_path\"")
        abs_path_list_q+=("'$abs_path'") 
        ends_list+=("$(basename "$abs_path")") 
    else
        return 4
    fi
    
}

add_to_exclude_list (){

    if [ "$#" -lt 1 ]; then
        err "Few arguments to add_to_exclude_list() function." 3 1 19; return $?
    elif [ "$#" -gt 1 ]; then
        err "Many arguments to add_to_exclude_list() function." 3 1 20; return $?
    fi

    if [ -z "$1" ]; then
        return 3
    elif [ -d "$1" ] || [ -e "$1" ] ; then 
        execlude_list=`realpath "$1"` 
    else
        return 21
    fi
}
extract_names(){
    # takes directory name and prints all file/subdir names inside 
    # stores the output into list, using convert_to_array
    # the directory, for example:
    # extract_names /home/user/Desktop
    # /home/user/Desktop/notes.txt
    # /home/user/Desktop/koko/koko
    if [ "$#" -ne 1 ]; then
        err "Invalid argument number to extract_names() function!" 3 1 3; return $?
    fi
    local tmpfile=`mktemp`
    local array=("${!1}")
    for i in "${array[@]}";do
        find "$i" -type d,f 1>> "$tmpfile" 2>/dev/null || return $? 
    done
    local output="`sort $tmpfile | uniq`"
    rm "$tmpfile"
    convert_to_arrayln_O "$output"
    remove_forward_slash list[@]
    append_forward_slash list[@]

}

getdirs() {
    array_length=${#ends_list[@]}
    for ((i=0; i<array_length; i++)); do
        echo -n "${ends_list[$i]}"
        if [ $i -ne $((array_length - 1)) ]; then
            echo -n "-"
        fi
    done
}


convert_to_arrayln_O() {
    # Convert to arrayln OPTIMIZED
    # Converts strings to array, each element is a line 
    # Stores the output in the global array $list
    # Returns 0 if no errors occurred
    # $1 is the string
    
    local input="$1"
    list=()

    # Temporarily change IFS to newline to handle spaces correctly
    while IFS=$'\n' read -r line; do
        list+=( "$line" )
    done <<< "$input"

    return 0
}



create_tar(){
    tar_commands_log_file="$backup_dir/tar_commands_log_file.txt"
    /usr/bin/env bash -c "/usr/bin/env tar fc \"$backup_file\" --use-compress-program=pigz $tar_arguments ${abs_path_list_q[*]}" 1>/dev/null  2>/dev/null  
    tar_exit_code=$?
    echo "[`date +%H:%M:%S-%D`] bash -c \"/usr/bin/env tar fc \\\"$backup_file\\\" --use-compress-program=pigz $tar_arguments ${abs_path_list_q[*]}\" 1>/dev/null  2>/dev/null  : $tar_exit_code" >> "$tar_commands_log_file" 
    return $tar_exit_code
}

archive(){
    
    if [ $# -lt 2 ]; then
        err "Few arguments to archive() function!" 3 1 6; return $?
    fi

    backup_dir=`realpath "$1"`
    local tar_arguments=$2
    shift 2

    backup_file="$backup_dir/backup[`getdirs`][`get_time`].tar.gz"
    
    created=1
    extract_names abs_path_list[@] || return $?

    extracted_ends_list=("${list[@]}")    
    convert_to_arrayln_O "$(ls "$backup_dir"/* 2>/dev/null | awk '/.*\.tar\.gz$/')"
    local duplicated_names=1
    for file in "${list[@]}"; do
        if [[ "$(basename "$file")" == "$(basename "$backup_file")" ]]; then
            duplicated_names=0
        else
            duplicated_names=1
        fi
        local tar_res="$(tar tf "$file" | sort | uniq)"
        convert_to_arrayln_O "$tar_res"
        local tar_list=("${list[@]}")
        compare_arrays tar_list[@]  extracted_ends_list[@]
        local result=$?
        if [ $result -eq 0 ] || [ $result -eq 2 ]; then
            if [ $created -eq 1 ]; then
                create_tar || { err "error at tar command $?, for more details open \"$tar_commands_log_file\"" 3 1 $? ; return $?;}
                created=0
                
                if [ $duplicated_names -eq 1 ]; then
                    rm "$file" || return $?
                fi
            elif [ $created -eq 0 ]; then
                if [ $duplicated_names -eq 1 ]; then
                    rm "$file" || return $?
                fi
            fi
        else        
            if [ $created -eq 1 ]; then
                create_tar  || return $?
                created=0
            fi
        fi
    done

    if [ $created -eq 1 ]; then
        create_tar || { err "error at tar command $?, for more details open \"$tar_commands_log_file\"" 3 1 $? ; return $?;}
        created=0
    fi
                   


}


if [ $# -lt 1 ]; then
    show_help; exit 1
fi

while [ $# -gt 0 ]; do
    case $1 in 
    -h|--help)
        show_help; exit 0
    ;;
    
    ## due to the fact that I fucked up in test, I did not test this option enough
    --tar_arguments)
        if [ -n "$2" ]; then        
            tar_arguments="$2"
            shift 2
        else
            err "--tar_arguments option requires argument." 3 0 7
        fi
    ;;
    
    -d|--directory|--destination)
        if [ -n "$2" ]; then        
            destination="$(realpath "$2" )"
            if [ ! -d "$destination" ]; then
                err "destination directory is invalid directory : $destination" 3 0 15
            fi
            shift 2
        else
            err "--destination option requires argument." 3 0 8
        fi
    ;;


   #### add it in the next update   
    # -e|--exclude)
    #     if [ -n "$2" ]; then        
    #         add_to_exclude_list "$2" || err  "$2 is not found" 3 2 0
    #         shift 2
    #     else
    #         err "--exclude option requires argument." 3 0 17
    #     fi
    # ;;
   #### add it in the next update
    # -m|--mode)
    #     if [ -n "$2" ]; then        
    #         set_mode "$2" || err  "$2 is not found" 3 2 0
    #         shift 2
    #     else
    #         err "--mode option requires argument." 3 0 18
    #     fi
    # ;;
    
    *)
        add_to_list "$1" || err  "$1 is not found" 3 2 0
        shift
    ;;
    esac
done



archive "$destination" "$tar_arguments" ${abs_path_list_dq[@]} || exit $?
echo "$backup_file"
