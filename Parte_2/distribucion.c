#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <time.h>

#define TOTAL_PAQUETES 300
#define CANT_RECEPTORES 4
#define CANT_ESCANERES 4
#define CANT_CLASIFICADORES 4
#define CANT_DESPACHADORES 3
#define CAP_ZONA1 15
#define CAP_ZONA2 15
#define CAP_PRIORIDAD 10
#define CAP_NORMAL 15
#define PRIORIDAD_NORMAL 0
#define PRIORIDAD_ALTA 1
#define PAQUETE_FIN -1

typedef struct {
    int id;
    int peso;
    int costo;
    int prioridad;
} Paquete;

typedef struct {
    Paquete datos[15];
    int frente;
    int final;
    int cantidad;
    int capacidad;
} Cola;

Cola zona1, zona2, cola_prioridad, cola_normal;

sem_t zona1_vacios, zona1_llenos, zona1_mutex;
sem_t zona2_vacios, zona2_llenos, zona2_mutex;
sem_t prioridad_vacios, normal_vacios, colas_mutex, items_finales;

int siguiente_id = 1;
int total_despachados = 0;
int prioritarios_consecutivos = 0;
pthread_mutex_t id_mutex = PTHREAD_MUTEX_INITIALIZER;

void inicializar_cola(Cola *cola, int capacidad) {
    cola->frente = 0;
    cola->final = 0;
    cola->cantidad = 0;
    cola->capacidad = capacidad;
}

void encolar(Cola *cola, Paquete paquete) {
    cola->datos[cola->final] = paquete;
    cola->final = (cola->final + 1) % cola->capacidad;
    cola->cantidad++;
}

Paquete desencolar(Cola *cola) {
    Paquete paquete = cola->datos[cola->frente];
    cola->frente = (cola->frente + 1) % cola->capacidad;
    cola->cantidad--;
    return paquete;
}

int numero_aleatorio(unsigned int *semilla, int minimo, int maximo) {
    return minimo + (rand_r(semilla) % (maximo - minimo + 1));
}

const char *texto_prioridad(int prioridad) {
    return prioridad == PRIORIDAD_ALTA ? "ALTA" : "NORMAL";
}

Paquete crear_paquete_fin(void) {
    Paquete p;
    p.id = PAQUETE_FIN;
    p.peso = 0;
    p.costo = 0;
    p.prioridad = PRIORIDAD_NORMAL;
    return p;
}

void *receptor(void *arg) {
    int nro = *((int *)arg);
    unsigned int semilla = (unsigned int)time(NULL) ^ (nro * 12345u);

    while (1) {
        int id;

        pthread_mutex_lock(&id_mutex);
        if (siguiente_id > TOTAL_PAQUETES) {
            pthread_mutex_unlock(&id_mutex);
            break;
        }
        id = siguiente_id++;
        pthread_mutex_unlock(&id_mutex);

        Paquete p;
        p.id = id;
        p.peso = numero_aleatorio(&semilla, 1, 20);
        p.costo = 0;
        p.prioridad = PRIORIDAD_NORMAL;

        sleep(numero_aleatorio(&semilla, 1, 2));

        printf("Receptor %d generó paquete %d con peso %d\n", nro, p.id, p.peso);

        sem_wait(&zona1_vacios);
        sem_wait(&zona1_mutex);
        encolar(&zona1, p);
        sem_post(&zona1_mutex);
        sem_post(&zona1_llenos);
    }

    return NULL;
}

void *escaner(void *arg) {
    int nro = *((int *)arg);
    unsigned int semilla = (unsigned int)time(NULL) ^ (nro * 23456u);

    while (1) {
        sem_wait(&zona1_llenos);
        sem_wait(&zona1_mutex);
        Paquete p = desencolar(&zona1);
        sem_post(&zona1_mutex);
        sem_post(&zona1_vacios);

        if (p.id == PAQUETE_FIN)
            break;

        sleep(numero_aleatorio(&semilla, 1, 3));

        p.prioridad = (p.peso > 10) ? PRIORIDAD_ALTA : PRIORIDAD_NORMAL;
        p.costo = p.peso * 100;

        printf("Escáner %d procesó paquete %d\n", nro, p.id);

        sem_wait(&zona2_vacios);
        sem_wait(&zona2_mutex);
        encolar(&zona2, p);
        sem_post(&zona2_mutex);
        sem_post(&zona2_llenos);
    }

    return NULL;
}

void *clasificador(void *arg) {
    int nro = *((int *)arg);
    unsigned int semilla = (unsigned int)time(NULL) ^ (nro * 34567u);

    while (1) {
        sem_wait(&zona2_llenos);
        sem_wait(&zona2_mutex);
        Paquete p = desencolar(&zona2);
        sem_post(&zona2_mutex);
        sem_post(&zona2_vacios);

        if (p.id == PAQUETE_FIN)
            break;

        sleep(numero_aleatorio(&semilla, 1, 2));

        if (p.prioridad == PRIORIDAD_ALTA) {
            sem_wait(&prioridad_vacios);
            sem_wait(&colas_mutex);
            encolar(&cola_prioridad, p);
            printf("Clasificador %d envió paquete %d a cola PRIORIDAD\n", nro, p.id);
            sem_post(&colas_mutex);
        } else {
            sem_wait(&normal_vacios);
            sem_wait(&colas_mutex);
            encolar(&cola_normal, p);
            printf("Clasificador %d envió paquete %d a cola NORMAL\n", nro, p.id);
            sem_post(&colas_mutex);
        }

        sem_post(&items_finales);
    }

    return NULL;
}

void *despachador(void *arg) {
    int nro = *((int *)arg);
    unsigned int semilla = (unsigned int)time(NULL) ^ (nro * 45678u);

    while (1) {
        sem_wait(&colas_mutex);
        if (total_despachados >= TOTAL_PAQUETES) {
            sem_post(&colas_mutex);
            break;
        }
        sem_post(&colas_mutex);

        sem_wait(&items_finales);
        sem_wait(&colas_mutex);

        if (total_despachados >= TOTAL_PAQUETES) {
            sem_post(&colas_mutex);
            break;
        }

        Paquete p;
        int saco_prioridad = 0;

        if (cola_prioridad.cantidad > 0 &&
            (prioritarios_consecutivos < 3 || cola_normal.cantidad == 0)) {

            p = desencolar(&cola_prioridad);
            prioritarios_consecutivos++;
            saco_prioridad = 1;

        } else if (cola_normal.cantidad > 0) {

            p = desencolar(&cola_normal);
            prioritarios_consecutivos = 0;
            saco_prioridad = 0;

        } else if (cola_prioridad.cantidad > 0) {

            p = desencolar(&cola_prioridad);
            prioritarios_consecutivos++;
            saco_prioridad = 1;

        } else {
            sem_post(&colas_mutex);
            continue;
        }

        total_despachados++;
        int numero_despachado = total_despachados;

        sem_post(&colas_mutex);

        if (saco_prioridad)
            sem_post(&prioridad_vacios);
        else
            sem_post(&normal_vacios);

        sleep(numero_aleatorio(&semilla, 1, 2));

        printf("Despachador %d despachó paquete %d - peso %d - prioridad %s - costo %d\n",
               nro, p.id, p.peso, texto_prioridad(p.prioridad), p.costo);

        if (numero_despachado == TOTAL_PAQUETES) {
            for (int i = 0; i < CANT_DESPACHADORES - 1; i++)
                sem_post(&items_finales);
        }
    }

    return NULL;
}

int main(void) {
    setbuf(stdout, NULL);

    printf("=============================================\n");
    printf(" CENTRO DE DISTRIBUCIÓN SPRINGFIELD\n");
    printf(" Procesando exactamente %d paquetes\n", TOTAL_PAQUETES);
    printf("=============================================\n\n");

    inicializar_cola(&zona1, CAP_ZONA1);
    inicializar_cola(&zona2, CAP_ZONA2);
    inicializar_cola(&cola_prioridad, CAP_PRIORIDAD);
    inicializar_cola(&cola_normal, CAP_NORMAL);

    sem_init(&zona1_vacios, 0, CAP_ZONA1);
    sem_init(&zona1_llenos, 0, 0);
    sem_init(&zona1_mutex, 0, 1);

    sem_init(&zona2_vacios, 0, CAP_ZONA2);
    sem_init(&zona2_llenos, 0, 0);
    sem_init(&zona2_mutex, 0, 1);

    sem_init(&prioridad_vacios, 0, CAP_PRIORIDAD);
    sem_init(&normal_vacios, 0, CAP_NORMAL);
    sem_init(&colas_mutex, 0, 1);
    sem_init(&items_finales, 0, 0);

    pthread_t receptores[CANT_RECEPTORES];
    pthread_t escaneres[CANT_ESCANERES];
    pthread_t clasificadores[CANT_CLASIFICADORES];
    pthread_t despachadores[CANT_DESPACHADORES];

    int ids_receptores[CANT_RECEPTORES];
    int ids_escaneres[CANT_ESCANERES];
    int ids_clasificadores[CANT_CLASIFICADORES];
    int ids_despachadores[CANT_DESPACHADORES];

    for (int i = 0; i < CANT_RECEPTORES; i++) {
        ids_receptores[i] = i + 1;
        pthread_create(&receptores[i], NULL, receptor, &ids_receptores[i]);
    }

    for (int i = 0; i < CANT_ESCANERES; i++) {
        ids_escaneres[i] = i + 1;
        pthread_create(&escaneres[i], NULL, escaner, &ids_escaneres[i]);
    }

    for (int i = 0; i < CANT_CLASIFICADORES; i++) {
        ids_clasificadores[i] = i + 1;
        pthread_create(&clasificadores[i], NULL, clasificador, &ids_clasificadores[i]);
    }

    for (int i = 0; i < CANT_DESPACHADORES; i++) {
        ids_despachadores[i] = i + 1;
        pthread_create(&despachadores[i], NULL, despachador, &ids_despachadores[i]);
    }

    /* Esperar a que terminen los 4 receptores. */
    for (int i = 0; i < CANT_RECEPTORES; i++)
        pthread_join(receptores[i], NULL);

    /* Insertar un paquete FIN por cada escáner. */
    for (int i = 0; i < CANT_ESCANERES; i++) {
        Paquete fin = crear_paquete_fin();
        sem_wait(&zona1_vacios);
        sem_wait(&zona1_mutex);
        encolar(&zona1, fin);
        sem_post(&zona1_mutex);
        sem_post(&zona1_llenos);
    }

    for (int i = 0; i < CANT_ESCANERES; i++)
        pthread_join(escaneres[i], NULL);

    /* Insertar un paquete FIN por cada clasificador. */
    for (int i = 0; i < CANT_CLASIFICADORES; i++) {
        Paquete fin = crear_paquete_fin();
        sem_wait(&zona2_vacios);
        sem_wait(&zona2_mutex);
        encolar(&zona2, fin);
        sem_post(&zona2_mutex);
        sem_post(&zona2_llenos);
    }

    for (int i = 0; i < CANT_CLASIFICADORES; i++)
        pthread_join(clasificadores[i], NULL);

    for (int i = 0; i < CANT_DESPACHADORES; i++)
        pthread_join(despachadores[i], NULL);

    printf("\n=============================================\n");
    printf(" PROCESAMIENTO FINALIZADO\n");
    printf(" Paquetes despachados: %d\n", total_despachados);
    printf("=============================================\n");

    sem_destroy(&zona1_vacios);
    sem_destroy(&zona1_llenos);
    sem_destroy(&zona1_mutex);
    sem_destroy(&zona2_vacios);
    sem_destroy(&zona2_llenos);
    sem_destroy(&zona2_mutex);
    sem_destroy(&prioridad_vacios);
    sem_destroy(&normal_vacios);
    sem_destroy(&colas_mutex);
    sem_destroy(&items_finales);
    pthread_mutex_destroy(&id_mutex);

    return 0;
}
