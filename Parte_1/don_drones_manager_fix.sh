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
        # FIX PROBLEMA 1 (conteo incorrecto de batería crítica):
        # Original: tail -n +2 "$ARCHIVO_FLOTA" | while ...; done
        # Con el pipe "|", Bash ejecuta el while en una SUBSHELL. CONTADOR se
        # incrementa dentro de esa subshell y el valor se pierde al terminar el
        # pipe, por lo que el shell principal siempre imprimía 0.
        # Solución: sustitución de proceso "< <(...)", así el while corre en el
        # shell actual y CONTADOR conserva su valor.
        while IFS=, read -r ID CAT MODELO BATERIA DISP; do
            if [ "$BATERIA" -lt "20" ]; then
                CONTADOR=$((CONTADOR + 1))
            fi
        done < <(tail -n +2 "$ARCHIVO_FLOTA")
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
        # FIX PROBLEMA 2 (drones sin batería asignados a repartos):
        # Original: if [ "$BATERIA_ACTUAL" > "20" ]; then
        # Dentro de [ ], ">" NO compara: es una redirección de salida. Bash
        # creaba un archivo vacío llamado "20" y el test quedaba [ "5" ], que
        # con un string no vacío siempre da verdadero -> se asignaba cualquier dron.
        # Solución: usar -gt para hacer una comparación numérica real.
        if [ "$BATERIA_ACTUAL" -gt "20" ]; then
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
