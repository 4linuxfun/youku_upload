#!/usr/bin/tclsh
#这个脚本用来上传文件
package require http
package require tls
package require md5
package require dns

set md5_check       0
#slice_length设置上传块大小，范围2048-10240
set slice_length    10240
set client_id       ""
set client_secret   ""
set redirect_uri    "http://localhost"

proc get_ipaddr {upload_server_uri} {
    	set token  [dns::resolve $upload_server_uri -timeout 60000]
        dns::wait $token
		if {[dns::status $token] != "ok"} {
		puts "[dns::error $token]"
        dns::cleanup $token
        get_ipaddr $upload_server_uri
        }
    set ip_addr [lindex [dns::address $token] 0]
    dns::cleanup $token
    #puts "IP_ADDR is :$ip_addr"
    return $ip_addr
}

#创建上传
proc input_upload {client_id access_t refresh_token} {
    #package require md5
    puts -nonewline "Please input the video title:"
    flush stdout
    set title   [gets stdin]
    puts -nonewline "Please input the video tags:"
    flush stdout
    set tags    [gets stdin]
    puts -nonewline "Please input the upload video path:"
    flush stdout
    set u_file  [gets stdin]
    puts "u_file is:$u_file"
    set file_name [file tail $u_file]
    #set file_md5 [md5::md5 -hex -file $u_file]
    if {[catch {exec md5sum $u_file} info]} {puts "MD5sum error:$info";exit 1}
    set file_md5 [lindex $info 0]
    #puts "md5 is:$file_md5"
    set file_size [file size $u_file]
    create_upload $client_id $access_t $refresh_token
}
proc create_upload {client_id access_t refresh_token} {
    upvar title title
    upvar tags tags
    upvar u_file u_file
    upvar file_name file_name
    upvar file_md5 file_md5
    upvar file_size file_size
    http::register https 443  [ list ::tls::socket -tls1 true ] 
    set url "https://openapi.youku.com/v2/uploads/create.json"
    set info "[http::formatQuery client_id $client_id access_token $access_t\
                                title $title tags $tags \
                        file_name $file_name file_md5 $file_md5 file_size $file_size]"
    puts "$info"
    if {[catch {set token [http::geturl $url?$info]} error]} {
        puts "Create ssl error"
        create_upload $client_id $access_t $refresh_token
        } 
    
    if {[lsearch [http::code $token] "201"]>=0} {
        puts "create OK"
        puts [http::code $token]
        } elseif {[lsearch [http::code $token] "1009"] >=0} {
            #token过期，需要刷新token
            source [file join [file dirname [info script]] "auth.tcl"]
            re_token $client_id $refresh_token
        } else {
            puts "There is something wrong"
            puts "[http::code $token]"
            puts "[http::data $token]"
            http::cleanup $token
            exit 1
            }
    #puts "[http::data $token]"
    set file_info [http::data $token]
    http::cleanup $token
    set tmp [split $file_info  "\":,\{\}"]
    while {[lsearch $tmp {}] >= 0} {
        set tmp [lreplace $tmp [lsearch $tmp {}] [lsearch $tmp {}]]
    }
    set upload_token        [dict get $tmp upload_token]
    set instant_upload_ok   [dict get $tmp instant_upload_ok]
    set upload_server_uri   [dict get $tmp upload_server_uri]
    if {![string compare -nocase "$instant_upload_ok"  "yes"]} {
        puts "The server have the same file,upload has been done"
        exit 1
        }

    
    #获取DNS解析地址
    set ip_addr [get_ipaddr $upload_server_uri]
    set token [open u_info.txt w]
    puts $token "${u_file}:${upload_token}:${ip_addr}"
    close $token
    puts "Starting Upload $file_name"
    upload_file $upload_token  $ip_addr $u_file $access_t
}

proc upload_file {upload_token  ip_addr u_file access_token} {
    upvar #0 slice_length slice_length
    set ext     [string trim [file extension $u_file] .]
    set url "http://${ip_addr}/gupload/create\_file"
    set post "[http::formatQuery upload_token $upload_token \
        file_size [file size $u_file] ext $ext slice_length  $slice_length ]"
    set token [http::geturl $url -query $post]
    #puts "[http::code $token]"
    if {"201" ni [http::code $token]} {
        puts "create error"
        } else {
            puts "[http::code $token]"
        }
    get_slice $ip_addr $upload_token $u_file $access_token
}

proc get_slice {ip_addr upload_token u_file access_token} {
    set url "http://${ip_addr}/gupload/new_slice"
    set token [http::geturl $url?upload_token=${upload_token}]
    #puts "[http::code $token]"
    set tmp [split [http::data $token] "\":,\{\}"]
    http::cleanup $token
    while {[lsearch $tmp {}] >= 0} {
        set tmp [lreplace $tmp [lsearch $tmp {}] [lsearch $tmp {}]]
    }
    puts "info is:$tmp"
    set slice_task_id [dict get $tmp slice_task_id]
    set offset [dict get $tmp offset]
    set length [dict get $tmp length]
    set transferred [dict get $tmp transferred]
    set finished [dict get $tmp finished]

    if {$finished == true } {
        puts "upload finished"
        commit_upload $access_token $upload_token $ip_addr
        } else {
            upload_slice $ip_addr $upload_token $slice_task_id $offset $length $u_file 
            #get_slice $ip_addr $upload_token $u_file $access_token
        }
}

proc upload_slice {ip_addr upload_token slice_task_id offset length u_file} {
    upvar #0 access_t access_token 
    global md5_check
    
    set fb  [open $u_file r]
    fconfigure $fb -encoding binary -translation binary
    seek $fb $offset
    set data [read $fb $length]
    close $fb
    
    if {$md5_check == 1} {
        set hash [md5::md5  -hex $data]
        set post [http::formatQuery upload_token $upload_token \
              slice_task_id $slice_task_id \
              offset $offset \
              length $length \
              hash  $hash]
    } else {
        set post [http::formatQuery upload_token $upload_token \
              slice_task_id $slice_task_id \
              offset $offset \
              length $length ]
    }
    
    set url "http://$ip_addr/gupload/upload_slice?$post"
    set token [http::geturl $url -query $data]
    #puts "[http::code $token]"
    set tmp [split [http::data $token] "\":,\{\}"]
    http::cleanup $token
    while {[lsearch $tmp {}] >= 0} {
        set tmp [lreplace $tmp [lsearch $tmp {}] [lsearch $tmp {}]]
    }
    puts "info is:$tmp"
    set slice_task_id [dict get $tmp slice_task_id]
    set offset [dict get $tmp offset]
    set length [dict get $tmp length]
    set transferred [dict get $tmp transferred]
    set finished [dict get $tmp finished]
   #==============
    if { [check $ip_addr $upload_token $access_token] == 4 } {
        #upload_slice $ip_addr $upload_token $slice_task_id $offset $length $u_file
        get_slice $ip_addr $upload_token $u_file $access_token
    }
    #close $tmp
}

proc commit_upload {access_token upload_token ip_addr} {
    global client_id
    http::register https 443  [ list ::tls::socket -tls1 true ] 
    set post "[http::formatQuery client_id $client_id \
                access_token $access_token upload_token $upload_token \
                upload_server_ip $ip_addr]"
    set url "https://openapi.youku.com/v2/uploads/commit.json"
    set token [http::geturl $url -query $post]
    #puts "commit [http::code $token]"
    #puts "[http::data $token]"
    http::cleanup $token
}

proc check {ip_addr upload_token access_token} {
    puts "checking upload status"
    #set query "[http::formatQuery upload_token $upload_token]"
    set url "http://${ip_addr}/gupload/check"
    set token [http::geturl ${url}?upload_token=${upload_token}]
    #puts [http::data $token]
    set tmp [split [http::data $token] "\":,\{\}"]
    http::cleanup $token
    while {[lsearch $tmp {}] >= 0} {
            set tmp [lreplace $tmp [lsearch $tmp {}] [lsearch $tmp {}]]
        }
    if {[catch {set status [dict get $tmp status]} info]} {puts "$tmp";exit 1}
    
    if {$status == 1} {
        puts "upload have OK"
        set ip_addr [dict get $tmp upload_server_ip]
        #puts "commit ip is:$ip_addr"
        commit_upload $access_token $upload_token $ip_addr
        file delete u_info.txt
        exit 1
    } elseif {$status != 4} {
        sleep [expr {60 * 1000}]
        check $ip_addr $upload_token $access_token
    } else {
        puts "Starting continue upload file"
        return 4
    }

}

if {![file exists token.json]} {
    puts "======================================================"
    puts "You first use this script,you have to auth for upload."
    puts "======================================================"
    #无token，即为首次使用，获取code和token
    source [file join [file dirname [info script]] "auth.tcl"]
    set code [auth $client_id $redirect_uri]
    get_token $client_id $client_secret $redirect_uri $code
} 
    #存在文件，通过upload返回判断是否过期
    set json [open token.json r]
    set date [split [read $json] "\n"]
    #puts "date is:$date"
    close $json
    set tmp [split $date "\":,\{\}"]
    #去掉空列
    while {[lsearch $tmp {}] >= 0} {
        set tmp [lreplace $tmp [lsearch $tmp {}] [lsearch $tmp {}]]
    }
   
    set access_t [dict get $tmp access_token]
    set refresh_t [dict get $tmp refresh_token]
    

switch [lindex $argv 0] {
    -c {
        #continue upload
        set token [open u_info.txt r]
        set data [read -nonewline $token]
        close $token
        #puts "data is:$data"
        set info [split $data ":"]
        set u_file              "[lindex $info 0]"
        set upload_token        "[lindex $info 1]"
        set ip_addr             "[lindex $info 2]"
        #puts "upload_token is:$upload_token"
        if { [check $ip_addr $upload_token $access_t] == 4 } {
            get_slice $ip_addr $upload_token $u_file $access_t
        }
    }
    default {
        input_upload $client_id $access_t $refresh_t
        }
}
