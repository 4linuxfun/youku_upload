#!/usr/bin/tclsh
#这个脚本用来获取youku授权

namespace eval cookies {}
proc cookies::processCookies {varname token} {
    upvar 1 $varname d
    foreach {name value} [http::meta $token] {
        if {[string equal -nocase $name "Set-cookie"]} {
            set value [lindex [split $value ";"] 0]
            if {[regexp "^(.*?)=(.*)\$" $value cname cvalue]} {
                dict set d $cname $cvalue
            }
    }
    }
}

proc cookies::prepareCookies {var} {
    set rc [list]
    dict for {name value} $var {
        lappend rc "$name=$value"
    }
    return [join $rc "; "]
}

proc getcode {varname token} {
    upvar 1 $varname c
    #puts "[http::meta $token]"
    foreach {name value} [http::meta $token] {
     if {[string equal -nocase $name "Location"]} {
            if {[string first "wrong" $value] >= 0} {
                puts "============================================="
                puts "account auth wrong!Please check your account."
                puts "============================================="
                exit 1
                }
            if {[regexp "code=(.*?)&(.*)" $value match code]} {
                set c "$code"
            }
        }
    }
    
    
}

proc auth {client_id redirect_uri} {
#请求授权
set post "[http::formatQuery client_id $client_id \
          response_type code redirect_uri $redirect_uri]"
http::register https 443  [ list ::tls::socket -tls1 true ] 
set token [http::geturl https://openapi.youku.com/v2/oauth2/authorize -query $post]
#puts "$post"
#puts "[http::code $token]"
#puts "[http::meta $token]"
#puts "[http::data $token]"

set c [dict create]
cookies::processCookies c $token
http::cleanup $token

puts -nonewline "Enter your accout:"
flush stdout
set account [gets stdin]
puts -nonewline "Enter your password:"
flush stdout
set password [gets stdin]

#global account password
set post "client_id=$client_id&response_type=code&redirect_uri=$redirect_uri&account=$account&password=$password"
http::register https 443  [ list ::tls::socket -tls1 true ] 
set token [http::geturl https://openapi.youku.com/v2/oauth2/authorize_submit \
           -query $post \
           -headers [list Cookie [cookies::prepareCookies $c]]]
set code [list]
getcode code $token
http::cleanup $token
#puts "code is:$code"
return $code
}

proc get_token {client_id client_secret redirect_uri code} {
#获取授权码
# -channel [open test.html wset token [http::geturl  https://openapi.youku.com/v2/oauth2/authorize -query $post]]
set json [open token.json w]

set post "client_id=$client_id&client_secret=$client_secret&grant_type=authorization_code&code=$code&redirect_uri=$redirect_uri"
http::register https 443  [ list ::tls::socket -tls1 true ] 
set token [http::geturl https://openapi.youku.com/v2/oauth2/token -query $post -channel $json]
#puts "[http::code $token]"
#puts "[http::meta $token]"
#puts "[http::data $token]"
close $json
http::cleanup $token
}

proc re_token { client_id refresh_token} {
    global client_secret
    set json [open token.json w]
    set post [http::formatQuery client_id $client_id \
              client_secret $client_secret grant_type refresh_token \
              refresh_token $refresh_token]
    http::register https 443  [ list ::tls::socket -tls1 true ] 
    set token [http::geturl https://openapi.youku.com/v2/oauth2/token -query $post -channel $json]
    http::cleanup $token
    close $json
}