#!/bin/sh
# Autor: Growth & Loyalty
# Como ejecutar este Script
# --------------------------------------
# 1. Ve a la ruta donde tienes tu archivo de usuarios
# 2. Abre una consola/terminal en esa ruta
# 3. Dar permisos al Script con el comando: chmod u+x script-users.sh
# 4. Setear las variables iniciales de Script antes de ejecutar
# 5. Ejecutar en la terminal : brew install dos2unix
# 6. Para correr el Script ejecuta el comando: ./script-users.sh  nombre_archivo
# --------------------------------------

# Variables iniciales de script
FILE_PROMOTION="promos.csv"
SCOPE="PROD"
METHOD="POST"
URL_TEMPLATE="https://internal-api.mercadolibre.com/internal/partners/process/user?env=${SCOPE}"
BODY_TEMPLATE='{"user_id": "_VALUE_1_", "promotion_id": "_VALUE_2_", "plan_id": "_VALUE_3_"}' # Cambiar segun la necesidad
SPLIT_LINES=500 #Numero de lineas a dividir por archivo


# Obtener archivo de usuarios
if [ -e "${1}" ];
then
    file_name="${1}"
else
    echo "File does not exist"
    exit 1
fi

# Creando archivos de salida
success_file="output-${file_name}"
error_file="error-${file_name}"

touch "${success_file}"
touch "${error_file}"

dos2unix "${file_name}"

# Partiendo el archivo de usuarios a "n" cantidad
total_lines=$(cat ${file_name} |wc -l )

if [ ${total_lines} -gt $SPLIT_LINES ]
then 
echo "Split ${file_name} in ${SPLIT_LINES} lines each file"
split -l "${SPLIT_LINES}" "${file_name}" "${file_name}"-
echo "Split done successfully"
echo "-------------------------------------"
echo ""
fi

function getPromotionXSite(){
    local p_deal="${1}"
    { (cat ${FILE_PROMOTION}; echo) |while IFS=, read deal_id promotion_id plan_id
    do
 
        if [ "$p_deal" = "$deal_id" ]
        then
            echo $promotion_id 
            break
        else
            continue
        fi
    done }< $FILE_PROMOTION
}

function getPlanBySite(){
    local p_deal="${1}"
    { (cat ${FILE_PROMOTION}; echo) |while IFS=, read deal_id promotion_id plan_id
    do

        if [ "$p_deal" = "$deal_id" ]
        then
            echo $plan_id 
            break
        else
            continue
        fi
    done }< $FILE_PROMOTION
}


function processParallel() {

    local file="${1}"
    echo "Start processing file ${file}"
   { (cat ${1} ; echo) | while IFS=, read user_id deal # Columnas del archivo CSV, separar con un espacio, cambiar segun la necesidad
    
    do	
        nivel=`curl -s "https://internal-api.mercadolibre.com/loyal/users/$user_id/level" | jq .level`
        #echo "user level -> $nivel" 
        if [ "$nivel" == "6" ]
        then
                echo "$user_id" >> "level6_user.csv"
        else 
                #echo "no es nivel 6"
                promotion_id=$(getPromotionXSite "$deal")
                plan_id=$(getPlanBySite "$deal")
                #echo "====> $promotion_id"
                #echo "====> $plan_id"
                url=`echo ${URL_TEMPLATE}`
                #body=`echo ${BODY_TEMPLATE} | sed -e "s/_VALUE_1_/${user_id}/g" -e "s/_VALUE_2_/${promotion_id}/g" -e "s/_VALUE_3_/${plan_id}/g"`
                body=`echo "{\"user_id\": \"${user_id}\", \"promotion_id\": \"${promotion_id}\", \"plan_id\": \"${plan_id}\"}"`
                # Usar para body
                #echo "$body" 
                #echo "url $url" 
                read  -ra response <<< $(curl -i -s -X ${METHOD} --header 'Content-Type: application/json' --data-raw "${body}" ${url})
                status=${response[1]}
                data=${response[@]} 
                #echo ${status}
                #echo ${body}
                if [ ${status} == 200 ]
                then 
                    # Agrega y ordena tu archvo de acuerdo a tus necesidades
                    echo ${user_id} , ${deal}, ${status} >> ${success_file}
                else 
                    # Arma el archivo de error con la misma estructura de tu archivo iniciar para luego ser reprocesado
                    echo ${user_id}, ${deal} >> ${error_file}
                fi
        fi
       
    done } < "${file}"

    echo "Done processing file ${file}"

}

#Si se supera las 500 lineas va a leer los archvios particionados, de lo contrario no

if [ ${total_lines} -gt $SPLIT_LINES ]
then 
for file in "${file_name}"-*;
do
    processParallel "${file}" &
done
else
    for file in "${file_name}";
do
    processParallel "${file}" &
done
fi
echo "Reprocesing errors ..."

cp ${error_file} "reprocess-${file_name}"

> ${error_file} #limpieza de archivo para reprocesamiento 
processParallel "reprocess-${file_name}"


success_lines=$(wc -l ${success_file})
error_lines=$(wc -l ${error_file})

echo "Total lines: $total_lines"
echo "Success lines vs Error lines: $success_lines / $error_lines"