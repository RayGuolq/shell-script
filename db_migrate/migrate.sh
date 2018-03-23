#!/bin/bash
MYSQL_HOST="192.168.1.1"
MYSQL_DB="test"
MYSQL_USER="root"
MYSQL_PASSWORD="root"
QUERY_DEVICE_COMMAND="select id,uuid,mac,name,model,vendor,user_id,add_time,binded,category from wd_device where category in (2,3,8,9)"
TMP_DIR="./tmp"
DEVICE_RESULT_FILE="$TMP_DIR/wd_device.txt"
FINAL_RESULT_DEVICE="device_result.txt"
FINAL_RESULT_DEVICE_DATA="device_data_result.txt"
#API_HOST="123.57.47.236"
API_HOST="101.200.219.159"
API_PORT="10010"
mkdir -p $TMP_DIR
echo "# create device result (old_id----uuid)" > $FINAL_RESULT_DEVICE
echo "# save device data result" > $FINAL_RESULT_DEVICE_DATA
mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DB -e "$QUERY_DEVICE_COMMAND" | awk -vOFS="|" '{split($0,arr,"\t"); print arr[1],arr[2],arr[3],arr[4],arr[5],arr[6],arr[7],arr[8],arr[9],arr[10]}' > $DEVICE_RESULT_FILE
# create device
#curl -v -H "Content-Type: application/json" -X POST -d '{"name":"name","type":1, "specID":2, "vendor":"vendor", "addrType":3, "addr":"address", "add_time":"2016-07-15 00:00:00", "old_id":1}'  http://localhost:10010/iot/api/v1/device
# save data
#curl -v -X POST -H "Content-type: application/json" -d '{"data":"data", "collectTime":"2016-07-08 15:00:00", "longitude":"longitude", "latitude":"latitude"}' http://localhost:10010/iot/api/v1/device/b32f5059-58ef-43be-86a1-b1e0281d3a84/data
OLD_IFS="$IFS"
# Starting from the second line read file
cat $DEVICE_RESULT_FILE | awk 'NR>1' | while read line
do
    #echo $line
    IFS="|"
    line_arr=($line)
    old_id=${line_arr[0]}
    type_temp=${line_arr[9]}
    specID_temp=1
    if [ $type_temp == 8 ]; then
        # OznerCup
        type_temp=1
        specID_temp=2
    elif [ $type_temp == 9 ]; then
        # Cuptime2
        type_temp=1
        specID_temp=3
    elif [ $type_temp == 3 ]; then
        # ozner tds meter
        type_temp=3
        specID_temp=4
    fi
    post_device_data="{\"name\":\"${line_arr[3]}\",\"type\":$type_temp, \"specID\":$specID_temp,\"vendor\":\"${line_arr[5]}\", \"addrType\":1,\"addr\":\"${line_arr[2]}\", \"add_time\":\"${line_arr[7]}\",\"old_id\":$old_id}"
    #echo $post_device_data
    create_device_url="http://$API_HOST:$API_PORT/iot/api/v1/device"
    #echo $create_device_url
    create_device_result=`curl -X POST -H "Content-type: application/json" -d "$post_device_data" $create_device_url 2>/dev/null`
    # curl result:{"status": 17, "message": "Already existed", "data": {"uuid": "72c5f4c7-5a12-49d0-941f-75bc3fc76ec1"}}
    echo $create_device_result
    device_uuid=`echo $create_device_result | awk -F '"uuid"' '{print $2}' | awk -F '"' '{print $2}'`
    temp_result=$old_id"----"$device_uuid
    # echo $temp_result >> $FINAL_RESULT_DEVICE
    sed -i '$a'$temp_result'' $FINAL_RESULT_DEVICE
    if [ ! -z $device_uuid ]; then
        #echo $device_uuid
        #save data start
        query_data_command="select data,add_time,longitude,latitude from wd_device_data where device_id=$old_id"
        data_result_file="$TMP_DIR/device_data_$old_id-id.txt"
        mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DB -e "$query_data_command" | awk -vOFS="|" '{split($0,arr,"\t"); print arr[1],arr[2],arr[3],arr[4]}' > $data_result_file
        # Invalid request: {"data":"{"tankStatus": 1, "failure": 0, "inletTDS": 100, "cleaningStatus": 0, "outletTDS": 9, "filterStatus": {"count": 5, "status": [354, 714, 714, 1434, 714]}, "workingStatus": 0}", "collectTime":"2016-07-12 00:36:13", "longitude":"0", "latitude":"0"}
        # {"tankStatus": 0, "failure": 0, "inletTDS": 100, "cleaningStatus": 1, "outletTDS": 30, "filterStatus": {"count": 5, "status": [{"life_percent": 31, "life": 115, "base_life": 360}, {"life_percent": 15, "life": 115, "base_life": 720}, {"life_percent": 15, "life": 115, "base_life": 720}, {"life_percent": 20, "life": 295, "base_life": 1440}, {"life_percent": 15, "life": 115, "base_life": 720}]}, "workingStatus": 0}
        cat $data_result_file | awk 'NR>1' | while read data_line
        do
            data_line_arr=($data_line)
            old_device_data=${data_line_arr[0]}
            device_data=$old_device_data
            if [ $type_temp == 2 ]; then
                #purifier device
                old_device_data1=`echo $old_device_data | awk -F '[' '{print $1}'`
                old_device_data2=`echo $old_device_data | awk -F '[' '{print $2}' | awk -F ']' '{print $2}'`
                filters_life_str=`echo $old_device_data | awk -F '[' '{print $2}' | awk -F ']' '{print $1}'`
                filters_life=(${filters_life_str//, /|})
                filter_life_1=${filters_life[0]}
                filter_life_2=${filters_life[1]}
                filter_life_3=${filters_life[2]}
                filter_life_4=${filters_life[3]}
                filter_life_5=${filters_life[4]}
                filter_base_life_1=360
                filter_base_life_2=720
                filter_base_life_3=720
                filter_base_life_4=1440
                filter_base_life_5=720
                filter_life_percent_1=$[filter_life_1*100/filter_base_life_1]
                filter_life_percent_2=$[filter_life_2*100/filter_base_life_2]
                filter_life_percent_3=$[filter_life_3*100/filter_base_life_3]
                filter_life_percent_4=$[filter_life_4*100/filter_base_life_4]
                filter_life_percent_5=$[filter_life_5*100/filter_base_life_5]
                status_json_str="[{\"life_percent\": $filter_life_percent_1, \"life\": $filter_life_1, \"base_life\": $filter_base_life_1}, {\"life_percent\": $filter_life_percent_2, \"life\": $filter_life_2, \"base_life\": $filter_base_life_2}, {\"life_percent\": $filter_life_percent_3, \"life\": $filter_life_3, \"base_life\": $filter_base_life_3}, {\"life_percent\": $filter_life_percent_4, \"life\": $filter_life_4, \"base_life\": $filter_base_life_4}, {\"life_percent\": $filter_life_percent_5, \"life\": $filter_life_5, \"base_life\": $filter_base_life_5}]"
                device_data=$old_device_data1$status_json_str$old_device_data2
            fi
            #echo ${device_data//\"/\\\"}
            post_devicedata_data="{\"data\":\"${device_data//\"/\\\"}\", \"collectTime\":\"${data_line_arr[1]}\", \"longitude\":\"${data_line_arr[2]}\", \"latitude\":\"${data_line_arr[3]}\"}"
            save_data_url="http://$API_HOST:$API_PORT/iot/api/v1/device/$device_uuid/data"
            curl -X POST -H "Content-type: application/json" -d "$post_devicedata_data" $save_data_url > /dev/null 2>&1
        done
        #save data end
    fi
done
IFS="$OLD_IFS"
