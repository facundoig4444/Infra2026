#!/bin/bash

ACCION=$1
PARAMETRO=$2
ARCHIVO_FLOTA="flota.csv"

if [ -z "$ACCION" ]; then
    echo -e "Error: Acción no especificada\n\tUso: ./don_drones_manager.sh <ACCIÓN> [PARÁMETRO]\n\tEj: ./don_drones_manager.sh bateria_critica"
    exit 1
fi

case $ACCION in

    bateria_critica)
        CONTADOR=0
        tail -n +2 "$ARCHIVO_FLOTA" | while IFS=, read -r ID CAT MODELO BATERIA DISP; do
            if [ "$BATERIA" -lt "20" ]; then
                CONTADOR=$((CONTADOR + 1))
            fi
        done
        echo "Drones con batería crítica: $CONTADOR"
        ;;

    asignar)
        DRON=$(grep "^$PARAMETRO," "$ARCHIVO_FLOTA")
        
        DISPONIBLE=$(echo "$DRON" | cut -d',' -f5)
        if [ "$DISPONIBLE" != "Si" ]; then
            echo "Error: el dron $PARAMETRO no está disponible."
            exit 1
        fi

        BATERIA_ACTUAL=$(grep "^$PARAMETRO," "$ARCHIVO_FLOTA" | cut -d',' -f4)
        if [ "$BATERIA_ACTUAL" > "20" ]; then
            sed -i "s/^$PARAMETRO,\(.*\),Si$/$PARAMETRO,\1,No/" "$ARCHIVO_FLOTA"
            echo "Dron $PARAMETRO asignado exitosamente."
        else
            echo "Error: Batería insuficiente."
            exit 1
        fi
        ;;

    *)
        echo "Acción no reconocida."
        exit 1
        ;;
    
esac