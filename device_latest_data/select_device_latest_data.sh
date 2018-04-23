#!/bin/bash

MYSQL_HOST="192.168.1.3"
IOT_MYSQL_DB="iot"
IOT_MYSQL_USER="iot"
IOT_MYSQL_PASSWORD="password"
IWATER_MYSQL_DB="iwater"
IWATER_MYSQL_USER="user"
IWATER_MYSQL_PASSWORD="1234"

TMP_DIR="./tmp"
DEVICE_RESULT_FILE="$TMP_DIR/device_uuids.txt"
FINAL_RESULT_FILE="$TMP_DIR/device_latest_TDS.txt"

mkdir -p $TMP_DIR
touch $DEVICE_RESULT_FILE
echo "device_name=====device_uuid=====tds=====time=====user_info" > $FINAL_RESULT_FILE

query_device_command="select uuid from device where type=2"
mysql -h$MYSQL_HOST -u$IOT_MYSQL_USER -p$IOT_MYSQL_PASSWORD $IOT_MYSQL_DB -e "$query_device_command" > $DEVICE_RESULT_FILE

device_index=1
cat $DEVICE_RESULT_FILE | awk 'NR>1' | while read line
do
    #echo $line
    device_uuid=($line)
    query_device_latest_data_command="select data,collect_time from device_data where uuid='$device_uuid' order by collect_time desc limit 1"
    query_data=`mysql -h$MYSQL_HOST -u$IOT_MYSQL_USER -p$IOT_MYSQL_PASSWORD $IOT_MYSQL_DB -e "$query_device_latest_data_command" | grep -v "data"`
    #echo $query_data
    tds=`echo $query_data | awk -F 'outletTDS": ' '{print $2}' | awk -F ',' '{print $1}'`
    if [ -z "$tds" ]; then
        tds="N/A"
    fi
    collect_time=`echo $query_data | awk -F '} ' '{print $2}'`
    if [ -z "$collect_time" ]; then
        collect_time="N/A"
    fi
    
    query_user_by_uuid_command="select username,usermobile from mb_user,wd_device,wd_device_user where mb_user.UserId=wd_device_user.user_id and wd_device_user.device_id=wd_device.device_id and wd_device_user.status=0 and device_uuid='$device_uuid' group by usermobile"
    user_info=`mysql -h$MYSQL_HOST -u$IWATER_MYSQL_USER -p$IWATER_MYSQL_PASSWORD $IWATER_MYSQL_DB -e "$query_user_by_uuid_command" | grep -v "usermobile"`
    #echo $user_info
    if [ -z "$user_info" ]; then
        user_info="N/A"
    fi

    device_name='device_'$((device_index++))
    echo $device_name=====$device_uuid=====$tds=====$collect_time=====$user_info >> $FINAL_RESULT_FILE
done
