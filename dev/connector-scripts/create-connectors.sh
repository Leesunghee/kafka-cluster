#!/bin/bash
################################################################################
# 1.File Name: eCore Kafka Connector script
# 2.Function: 
# 3.Comment: eCore Kafka Connector script
# 4.Author:eCore - Euimin Hwang
# 5.Date: 2021.10.08
# 6.History: init
#
#################################################################################
#-------------------------------------------------------------------------------#
# 변수정의
#-------------------------------------------------------------------------------#

#+++++++++++++++++++++++++++++++++#
# 가변 변수 (사용자 정의 변수)
#+++++++++++++++++++++++++++++++++#

###CONNECT_IP=10.110.120.122
CONNECT_IP=$CONNECTOR_GENERATOR_HOST_IP
CONNECT_PORT=$CONNECTOR_GENERATOR_HOST_PORT

#+++++++++++++++++++++++++++++++++#
# 고정 변수 
#+++++++++++++++++++++++++++++++++#

#+++++++++++++++++++++++++++++++++#
# Connector 설정
#+++++++++++++++++++++++++++++++++#


#-------------------------------------------------------------------------------#
# 함수정의
#-------------------------------------------------------------------------------#

function get_connect_status {
	
	connect_reponse_code=$(curl -X GET -L -s -o /dev/null -w "%{http_code}\n" http://$CONNECT_IP:$CONNECT_PORT/connectors)
	echo $connect_reponse_code

}

function create_connectors {
	
	local max=60
	local delay=5

	for (( i=1; i<$max; i++ ));
	do

	if [ "$(get_connect_status)" ==  "200" ]; then
		
		echo "Succeded connected Kafka Connect (http response code : $(get_connect_status))"
		create_source_connectors
		sleep $delay
		create_sink_connector
		return
	else
		echo "Trying to Connect with Kafka Connect $i/60 attempts... (http response code : $(get_connect_status))" 	
		if [ $i -eq 60 ]
		then
			echo "Failed to connect Kafka Connect ..." 
			echo "Failed to Create Kafka Connectors..." 
			echo "Please check the Kafka Connect Status. "
		fi		
		sleep $delay
              
	fi	

	done 

}

function create_source_connectors {
	
	local response_code=$(curl -X POST -H "Content-Type: application/json" -L -s -o /dev/null -w "%{http_code}\n" -d @./source/postgres-cdc-source-connector.json http://$CONNECT_IP:$CONNECT_PORT/connectors)
	
	if [ "$response_code" == "201" ]; then

		echo "Succeded created Kafka Source connector (http response code : $response_code)"

	elif [ "$response_code" == "409" ]; then
		
		echo "Source connector already exists. Failed to create Kafka Source connector (http response code : $response_code)"

	else
		echo "Failed to create Kafka Source connector (http response code : $response_code)"

	fi

}

function create_sink_connector {

	local response_code=$(curl -X POST -H "Content-Type: application/json" -L -s -o /dev/null -w "%{http_code}\n" -d @./sink/postgres-sink-connector.json http://$CONNECT_IP:$CONNECT_PORT/connectors)

	if [ "$response_code" == "201" ]; then

	echo "Succeded created Kafka Sink connector (http response code : $response_code)"

	elif [ "$response_code" == "409" ]; then

	echo "Sink connector already exists. Failed to create Kafka Source connector (http response code : $response_code)"

	else
	echo "Failed to create Kafka Sink connector (http response code : $response_code)"

	fi
}

function generate_connector_json {

	echo "Generate source/sink connector json files"

	cat ./source/postgres-cdc-source-connector.base | sed -e 's%${SCHEMA_REGISTRY_URL}%'"$SCHEMA_REGISTRY_URL"'%g' > ./source/postgres-cdc-source-connector.json
	cat ./sink/postgres-sink-connector.base | sed -e 's%${SCHEMA_REGISTRY_URL}%'"$SCHEMA_REGISTRY_URL"'%g' > ./sink/postgres-sink-connector.json

}

#-------------------------------------------------------------------------------#
# execute
#-------------------------------------------------------------------------------#

generate_connector_json
create_connectors
