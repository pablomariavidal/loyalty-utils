#!/bin/bash

app="$1"
ip="$2"
output_file="$3"
fury_token="$(fury get-token)"
echo $fury_token
echo "obteniendo jstack de la app: $app en la maquina: $ip"

url='https://api.furycloud.io/instance_commands/jstack2/executions'

result="$(curl -H 'origin: https://web.furycloud.io' \
  -H "accept-encoding: gzip, deflate, br" \
  -H "accept-language: es-ES,es;q=0.9,en;q=0.8,pt;q=0.7" \
  -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36" \
  -H 'content-type: application/json' \
  -H "accept: */*" \
  -H 'referer: https://web.furycloud.io/' \
  -H 'authority: api.furycloud.io' \
  -H "x-tiger-token: $fury_token" \
  --data-binary '{"instance_private_ip":"'"$ip"'","parameters":[],"application":"'"$app"'"}' \
  --compressed "$url" )"

 echo $result

 execution_url="$(echo $result | jq .execution_url)"
 echo $execution_url
 execution_url_clean="$(echo "$execution_url" | sed -e 's/^"//' -e 's/"$//')" # remove doble quotes
 command_hash="$(echo ${execution_url_clean##*/})"

 jstack_url="http://fury-instance-proxy.furycloud.io/commands/$command_hash"
echo $jstack_url
 curl -X GET "$jstack_url" -o "$output_file" -H "x-tiger-token: $fury_token" \
 

 echo "jstack exitoso guardado en: $output_file"

