#!/bin/bash
#set -x

function domainConnection() {
    local domain=$1
 
    local last_command=`wget --spider -S -q ${domain} 2>&1 | grep "HTTP/" | awk '{print $2}'`  
    if [[ ${last_command} == *"200"* ]] || [[ ${last_command}  == *"301"* ]]; then
        echo "Online" ${last_command}
    else
        echo "Offline" ${last_command}
    fi
 
    return 0
}    


if [[  -f /usr/bin/wget ]] ; then
    echo "wget ok"
else 
    echo "wget not installed"
    exit 1

fi

#Start to collect host data from here 
    # Check if connected to Internet or not
    internet=$(domainConnection google.com)

    # Check Internal IP
    internalip=$(hostname -i)

    # Check External IP
    externalip=$(curl -s ipecho.net/plain;echo)





count_only_once=0
counter=0

get_request_ips(){
    local date_tooday=$(date "+%d/%b/%Y")
    local condidate=$(docker exec proxyserver cat /var/log/nginx/access.log | grep "${date_tooday}" |  grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" |  sort | uniq -c | sort -n | tail -n 5  )
    local get_ip_pool=$(echo  "$condidate" | awk '{print $2}')
        
    for ipaddr  in ${get_ip_pool[@]} ; do
        validate_ip=`valid_ip $ipaddr`
        #echo "$validate_ip"
        if [[ $validate_ip == "valid"* ]] ; then
            counter=$((counter+1))                      
            get_counted_per_ip=$(echo "$condidate" | grep "${ipaddr}" | awk '{print $1}')
            local data=$(get_geo_ip  ${ipaddr} ${get_counted_per_ip})
            local data_json=$(cat <<EOF
, "Geo_data_per_ip $externalip $counter":"City_Counry_Region_ip_counter $data"
EOF
)
            local para+=$(cat <<EOF
$data_json
EOF
)
        fi  
    done
    counter=0           
}

function valid_ip() {
    local  ip_str=$1
    local rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
    if [[ $ip_str =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
        echo "valid:     "$ip_str
    else
      echo "not valid: "$ip_str
    fi
    return 0
}

get_geo_ip(){

    PUBLIC_IP=$1
    counted=$2
    curl -s https://ipinfo.io/${PUBLIC_IP} | \
        jq '.city, .country , .region ' | tr -d '"' |   \
            while read -r CITY ; do
                read -r COUNTRY 
                read -r REGION  
                if [[ ${CITY} == "" ]] ; then 
                    CITY="no_data"
                fi  
                if [[ ${COUNTRY} == "" ]] ; then 
                    COUNTRY="no_data"
                fi
                if [[ ${REGION} == "" ]] ; then 
                    REGION="no_data"
                fi
                echo "${CITY} ${COUNTRY} ${PUBLIC_IP} ${counted}" 
                done
}


time_to_parse_log() {
        local state=$1
    local H=$(date +%H)
    if (( 15 <= 10#$H && 10#$H < 16 )); then 
        if [[ $state -lt 1 ]] ; then 
            echo "true_run"
        fi  
    else 
       echo "false_run"     
    fi

}





while true; do
        
        params=""
        params_2=""

        now=$(date -u +%Y-%m-%dT%H:%M:%S)
        #time_stamp_milisec=$(($(date +%s%N)/1000000))

        


# Check RAM , Disk , and load avg  Usages on host server 
        availablemem=$(free -h | awk '/^Mem/ {print $7}'| sed 's/.$//' )
        usedmem=$(free -h | awk '/^Mem/ {print $3}' | sed 's/.$//' )
        totalmem=$(free -h | awk '/^Mem/ {print $2}' | sed 's/.$//' )
        diskusagefree=$(df -h| grep 'Filesystem\|/dev/xv*' | awk '{print $5}' | grep -v "Use%" | sed 's/.$//' | awk '{print 100 - $1}')
        load_avg=$(top -n 1 -b | grep "load average:" | awk '{print $12 $13 $14}')


        params=$(cat <<EOF
"LogTime":"$now" , "HostIpLanAddr_$externalip":"$internalip" , "HostIpWanAddr_$externalip":"$externalip" , "HostInternet_$externalip":"$internet" , "HostMemAvailable_$externalip":$availablemem , "HostMemUsed_$externalip":$usedmem , "HostMemTotal_$externalip":$totalmem , "HostDiskFree%_$externalip":$diskusagefree ,"HostLoadAVG_$externalip":"$load_avg"
EOF
)

        params_2=$(cat <<EOF
"LogTime":"$now"  
EOF
)
        







#nginx log parser by geo ip count all connections and show geo position
         
        run_parser=$(time_to_parse_log ${count_only_once})
        if [[ $run_parser == "true_run" ]] ; then
            get_ip_info=$(get_request_ips)
            #echo $get_ip_info
            count_only_once=$((count_only_once+1)) 
                
                     
            
        

        params_2+=$(cat <<EOF
$get_ip_info
EOF
)
#Post to elasticsearch nginx log info 

        echo {${params_2}} > /tmp/bx2 
        #cat /tmp/bx2
        curl -u user_name:password --silent --show-error --fail -XPOST -H'Content-Type: application/json' "elasticsearch_domain_or_ip/name_of_index/version1"  --data-binary @/tmp/bx2


        
        fi
        if [[ $run_parser == "false_run" ]] && [[ $count_only_once == 1 ]] ; then
            count_only_once=0
        fi


        
        
        
        
#Get all data from all Dockers running on the host here        
        getalldockers=()
        getalldockers=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" )
        getalldockersname=()
        getalldockersname=$(echo  "$getalldockers" | awk '{print $1}'| grep -v "NAME")



        for docker  in ${getalldockersname[@]} ; do
            
            get_docker_memory=$(echo  "$getalldockers" | grep "$docker" | awk '{print $8}' | sed 's/.$//' )
            if [[ -z ${get_docker_memory} ]] ; then
                get_docker_memory=$(echo  "$getalldockers" | grep "$docker" | awk '{print $6}' | sed 's/.$//' )
            fi  
            get_docker_cpu=$(echo  "$getalldockers" | grep "$docker" | awk '{print $2}' | sed 's/.$//')
            
            if [[ ${docker}  == *"proxyserver"* ]]; then
                time_wait=$(docker exec "$docker" netstat -an | grep :80 | grep  TIME_WAIT | wc -l)
                total_connection=$(docker exec "$docker" netstat -an | grep :80 | wc -l)
                established_conn=$(docker exec "$docker" netstat -an | grep :80 | grep ESTABLISHED | wc -l)
                params+=$( cat <<EOF
, "TIME_WAIT_$docker_$externalip":$time_wait , "ESTABLISHED_$docker_$externalip":$established_conn , "Total_$docker_$externalip":$total_connection
EOF
)
            
            fi
            
            #echo "${get_docker_memory}"
            params+=$( cat <<EOF
, "DocMemUsage%_$docker$externalip":$get_docker_memory ,  "DocCpuUsage%_$docker$externalip":$get_docker_cpu
EOF
)
            

            
        done    
            
#Post to elasticsearch docker data and host  

        echo {${params}} > /tmp/bx 
        #cat /tmp/bx
        curl -u user_name:password --silent --show-error --fail -XPOST -H'Content-Type: application/json' "elasticsearch_domain_or_ip/name_of_index/version1"  --data-binary @/tmp/bx 
        
        
 


sleep 60
done


