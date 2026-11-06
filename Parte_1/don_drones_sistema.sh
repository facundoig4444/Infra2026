#!/bin/bash

# ============================================================
# DON DRONES - SISTEMA DE GESTIÓN DE FLOTA
# Obligatorio de Infraestructura
#
# Funcionalidades incluidas:
#   - Usuario inicial admin/admin
#   - Registro de usuarios
#   - Inicio de sesión
#   - Cierre de sesión
#   - Alta de drones con ID automático
#   - Asignación de drones a reparto
#   - Actualización de batería y disponibilidad
#   - Reporte de drones con batería crítica (< 20%)
#   - Salida del sistema
#
# Archivos utilizados:
#   - usuarios.csv
#   - flota.csv
# ============================================================


# ============================================================
# ETAPA 1 - CONFIGURACIÓN GENERAL
# ============================================================

ARCHIVO_USUARIOS="usuarios.csv"
ARCHIVO_FLOTA="flota.csv"

USUARIO_ACTUAL=""


# ============================================================
# ETAPA 2 - INICIALIZACIÓN DEL SISTEMA
# ============================================================

inicializar_sistema() {

    # Si el archivo de usuarios no existe, se crea.
    # También se agrega el usuario inicial obligatorio admin/admin.
    if [ ! -f "$ARCHIVO_USUARIOS" ]; then
        echo "usuario,password" > "$ARCHIVO_USUARIOS"
        echo "admin,admin" >> "$ARCHIVO_USUARIOS"
    fi

    # Si el archivo de flota no existe, se crea con su encabezado.
    if [ ! -f "$ARCHIVO_FLOTA" ]; then
        echo "ID,Categoria,Modelo,Bateria,Disponible" > "$ARCHIVO_FLOTA"
    fi
}


# Comparaciones literales: no interpretar entradas como patrones.
usuario_existe() {
    local usuario_guardado password_guardado
    while IFS=, read -r usuario_guardado password_guardado; do
        if [ "$usuario_guardado" = "$1" ]; then
            return 0
        fi
    done < <(tail -n +2 "$ARCHIVO_USUARIOS")
    return 1
}

credenciales_validas() {
    local usuario_guardado password_guardado
    while IFS=, read -r usuario_guardado password_guardado; do
        if [ "$usuario_guardado" = "$1" ] && [ "$password_guardado" = "$2" ]; then
            return 0
        fi
    done < <(tail -n +2 "$ARCHIVO_USUARIOS")
    return 1
}

buscar_dron() {
    local fila id_guardado
    while IFS= read -r fila; do
        id_guardado="${fila%%,*}"
        if [ "$id_guardado" = "$1" ]; then
            printf '%s\n' "$fila"
            return 0
        fi
    done < <(tail -n +2 "$ARCHIVO_FLOTA")
    return 1
}

# Validar el rango como texto evita desbordamientos numéricos.
bateria_valida() {
    [[ "$1" =~ ^0*(100|[0-9]{1,2})$ ]]
}

# Reescribir la fila literalmente permite modelos con /, & o barras inversas.
reemplazar_dron() {
    local temporal fila id_guardado
    temporal=$(mktemp "${ARCHIVO_FLOTA}.XXXXXX") || return 1

    if ! (
        while IFS= read -r fila || [ -n "$fila" ]; do
            id_guardado="${fila%%,*}"
            if [ "$id_guardado" = "$1" ]; then
                printf '%s\n' "$2" || exit 1
            else
                printf '%s\n' "$fila" || exit 1
            fi
        done < "$ARCHIVO_FLOTA"
    ) > "$temporal"; then
        rm -f -- "$temporal"
        return 1
    fi

    if ! mv -- "$temporal" "$ARCHIVO_FLOTA"; then
        rm -f -- "$temporal"
        return 1
    fi
}

# ============================================================
# ETAPA 3 - REGISTRO DE USUARIOS
# ============================================================

registrar_usuario() {

    echo
    echo "=============================="
    echo "      REGISTRO DE USUARIO"
    echo "=============================="

    read -r -p "Ingrese nombre de usuario: " usuario

    # Validar que el usuario no esté vacío.
    if [ -z "$usuario" ]; then
        echo "Error: el usuario no puede estar vacío."
        return
    fi

    if [[ "$usuario" == *,* ]]; then
        echo "Error: el campo usuario no puede contener comas."
        return 1
    fi

    # Validar que el usuario no exista previamente.
    if usuario_existe "$usuario"; then
        echo "Error: el usuario '$usuario' ya existe."
        return
    fi

    read -r -s -p "Ingrese contraseña: " password
    echo

    # Validar que la contraseña no esté vacía.
    if [ -z "$password" ]; then
        echo "Error: la contraseña no puede estar vacía."
        return
    fi

    if [[ "$password" == *,* ]]; then
        echo "Error: el campo password no puede contener comas."
        return 1
    fi

    if ! printf '%s,%s\n' "$usuario" "$password" >> "$ARCHIVO_USUARIOS"; then
        echo "Error: no se pudo guardar el usuario."
        return 1
    fi

    echo "Usuario registrado correctamente."
}


# ============================================================
# ETAPA 4 - LOGIN
# ============================================================

login() {

    echo
    echo "=============================="
    echo "          INICIAR SESIÓN"
    echo "=============================="

    read -r -p "Usuario: " usuario

    if [ -z "$usuario" ]; then
        echo "Error: el usuario no puede estar vacío."
        return 1
    fi

    read -r -s -p "Contraseña: " password
    echo

    if [ -z "$password" ]; then
        echo "Error: la contraseña no puede estar vacía."
        return 1
    fi

    # Se busca coincidencia exacta usuario,contraseña.
    if credenciales_validas "$usuario" "$password"; then
        USUARIO_ACTUAL="$usuario"
        echo "Login correcto. Bienvenido $USUARIO_ACTUAL."
        return 0
    else
        echo "Error: usuario o contraseña incorrectos."
        return 1
    fi
}


# ============================================================
# ETAPA 5 - LOGOUT
# ============================================================

logout() {

    echo
    echo "Cerrando sesión de $USUARIO_ACTUAL..."
    USUARIO_ACTUAL=""
    echo "Sesión cerrada correctamente."
}


# ============================================================
# ETAPA 6 - VALIDACIÓN DE CATEGORÍAS
# ============================================================

categoria_valida() {

    case "$1" in
        Scout|Cargo|Heavy|Cooler|Racer)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


# ============================================================
# ETAPA 7 - GENERACIÓN AUTOMÁTICA DEL ID DEL DRON
# ============================================================

generar_id() {

    categoria="$1"

    # Se toman las primeras 3 letras de la categoría
    # y se convierten a mayúsculas.
    prefijo=$(echo "${categoria:0:3}" | tr '[:lower:]' '[:upper:]')

    # Buscar el último número utilizado para esa categoría.
    ultimo_numero=$(grep "^$prefijo-" "$ARCHIVO_FLOTA" \
        | cut -d',' -f1 \
        | cut -d'-' -f2 \
        | sort -n \
        | tail -1)

    if [ -z "$ultimo_numero" ]; then
        numero=1
    else
        numero=$((10#$ultimo_numero + 1))
    fi

    # Ejemplo: CAR-001
    printf "%s-%03d" "$prefijo" "$numero"
}


# ============================================================
# ETAPA 8 - ALTA DE DRONES
# ============================================================

ingresar_dron() {

    echo
    echo "=============================="
    echo "        INGRESAR DRON"
    echo "=============================="

    echo "Categorías disponibles:"
    echo "1. Scout"
    echo "2. Cargo"
    echo "3. Heavy"
    echo "4. Cooler"
    echo "5. Racer"
    echo

    read -r -p "Ingrese categoría: " categoria

    if ! categoria_valida "$categoria"; then
        echo "Error: categoría inválida."
        return
    fi

    read -r -p "Ingrese modelo: " modelo

    if [ -z "$modelo" ]; then
        echo "Error: el modelo no puede estar vacío."
        return
    fi

    if [[ "$modelo" == *,* ]]; then
        echo "Error: el campo modelo no puede contener comas."
        return 1
    fi

    read -r -p "Ingrese batería (0-100): " bateria

    if ! bateria_valida "$bateria"; then
        echo "Error: la batería debe ser un número entero entre 0 y 100."
        return 1
    fi

    read -r -p "Disponible (Si/No): " disponible

    if [ "$disponible" != "Si" ] && [ "$disponible" != "No" ]; then
        echo "Error: debe ingresar Si o No."
        return
    fi

    id=$(generar_id "$categoria")

    if ! printf '%s,%s,%s,%s,%s\n' "$id" "$categoria" "$modelo" "$bateria" "$disponible" >> "$ARCHIVO_FLOTA"; then
        echo "Error: no se pudo guardar el dron."
        return 1
    fi

    echo
    echo "Dron ingresado correctamente:"
    echo "$id - $categoria - $modelo - $bateria% - $disponible"
}


# ============================================================
# ETAPA 9 - ASIGNACIÓN DE DRON A REPARTO
# ============================================================

asignar_dron() {

    echo
    echo "=============================="
    echo "      ASIGNAR DRON"
    echo "=============================="

    read -r -p "Ingrese ID del dron: " id

    # Buscar el dron exacto en el archivo.
    dron=$(buscar_dron "$id")

    # Validar que exista.
    if [ -z "$dron" ]; then
        echo "Error: el dron $id no existe."
        return
    fi

    bateria=$(echo "$dron" | cut -d',' -f4)
    disponible=$(echo "$dron" | cut -d',' -f5)

    # Validar disponibilidad.
    if [ "$disponible" != "Si" ]; then
        echo "Error: el dron $id no está disponible."
        return
    fi

    # Reutilización de la lógica corregida:
    # un dron con batería menor a 20% no puede asignarse.
    if [ "$bateria" -lt 20 ]; then
        echo "Error: batería insuficiente."
        return
    fi

    # Cambiar disponibilidad de Si a No.
    if ! reemplazar_dron "$id" "${dron%,*},No"; then
        echo "Error: no se pudo guardar la asignación."
        return 1
    fi

    echo "Dron $id asignado correctamente."
}


# ============================================================
# ETAPA 10 - ACTUALIZACIÓN DE DRON
# ============================================================

actualizar_dron() {

    echo
    echo "=============================="
    echo "      ACTUALIZAR DRON"
    echo "=============================="

    read -r -p "Ingrese ID del dron: " id

    dron=$(buscar_dron "$id")

    # Validar existencia.
    if [ -z "$dron" ]; then
        echo "Error: el dron $id no existe."
        return
    fi

    categoria=$(echo "$dron" | cut -d',' -f2)
    modelo=$(echo "$dron" | cut -d',' -f3)

    read -r -p "Nueva batería (0-100): " bateria

    if ! bateria_valida "$bateria"; then
        echo "Error: la batería debe ser un número entero entre 0 y 100."
        return 1
    fi

    read -r -p "Disponible (Si/No): " disponible

    if [ "$disponible" != "Si" ] && [ "$disponible" != "No" ]; then
        echo "Error: debe ingresar Si o No."
        return
    fi

    # Reemplazar la línea correspondiente al dron.
    if ! reemplazar_dron "$id" "$id,$categoria,$modelo,$bateria,$disponible"; then
        echo "Error: no se pudo guardar la actualización."
        return 1
    fi

    echo "Dron $id actualizado correctamente."
}


# ============================================================
# ETAPA 11 - REPORTE DE BATERÍA CRÍTICA
# ============================================================

reporte_bateria_critica() {

    echo
    echo "=============================="
    echo "   REPORTE DE BATERÍA CRÍTICA"
    echo "=============================="

    contador=0

    # Se evita usar "tail | while" para no perder
    # el valor del contador debido al subshell.
    while IFS=, read -r id categoria modelo bateria disponible; do

        if [ "$bateria" -lt 20 ]; then

            contador=$((contador + 1))

            echo "$id - $categoria - $modelo - $bateria% - $disponible"
        fi

    done < <(tail -n +2 "$ARCHIVO_FLOTA")

    echo
    echo "Drones con batería crítica: $contador"
}


# ============================================================
# ETAPA 12 - MENÚ PRINCIPAL
# ============================================================

menu_principal() {

    while [ -n "$USUARIO_ACTUAL" ]; do

        echo
        echo "=============================="
        echo "        MENÚ PRINCIPAL"
        echo " Usuario: $USUARIO_ACTUAL"
        echo "=============================="
        echo "1. Ingresar dron"
        echo "2. Asignar dron a reparto"
        echo "3. Actualizar dron"
        echo "4. Reporte de batería crítica"
        echo "5. Log Out"
        echo "6. Salir"
        echo "=============================="

        read -r -p "Seleccione una opción: " opcion

        case "$opcion" in

            1)
                ingresar_dron
                ;;

            2)
                asignar_dron
                ;;

            3)
                actualizar_dron
                ;;

            4)
                reporte_bateria_critica
                ;;

            5)
                logout
                ;;

            6)
                echo "Saliendo del sistema..."
                exit 0
                ;;

            *)
                echo "Opción inválida."
                ;;

        esac

    done
}


# ============================================================
# ETAPA 13 - MENÚ DE SESIÓN
# ============================================================

menu_sesion() {

    while true; do

        echo
        echo "=============================="
        echo "          DON DRONES"
        echo "=============================="
        echo "1. Sign Up"
        echo "2. Log In"
        echo "3. Salir"
        echo "=============================="

        read -r -p "Seleccione una opción: " opcion

        case "$opcion" in

            1)
                registrar_usuario
                ;;

            2)
                if login; then
                    menu_principal
                fi
                ;;

            3)
                echo "Saliendo del sistema..."
                exit 0
                ;;

            *)
                echo "Opción inválida."
                ;;

        esac

    done
}


# ============================================================
# ETAPA 14 - INICIO DEL PROGRAMA
# ============================================================

inicializar_sistema
menu_sesion
