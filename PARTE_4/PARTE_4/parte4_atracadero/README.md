# Parte 4 - Virtualización: Sistema de acceso a un atracadero

## Arquitectura

La solución utiliza cuatro microservicios independientes:

- `coordinador`: administra el único atracadero.
- `barco1`: microservicio de Barco 1.
- `barco2`: microservicio de Barco 2.
- `barco3`: microservicio de Barco 3.

Cada barco está implementado en Ada y se ejecuta como un proceso independiente dentro de su propio contenedor Docker. El coordinador también está implementado en Ada.

La comunicación se realiza mediante TCP sobre la red interna de Docker Compose.

```text
Barco 1 ----\
Barco 2 ----- > TCP ---> Coordinador ---> Atracadero único
Barco 3 ----/
```

El coordinador mantiene una única variable de estado: el identificador del barco que actualmente ocupa el atracadero. Como el coordinador procesa las solicitudes de autorización de forma serial, nunca puede otorgar dos autorizaciones simultáneamente.

## Protocolo de comunicación

Los barcos envían los siguientes mensajes:

- `REQUEST <id>`: solicita autorización.
- `RELEASE <id>`: informa que abandona el atracadero.

El coordinador responde:

- `GRANTED`: acceso concedido.
- `WAIT <id>`: atracadero ocupado; el barco debe esperar.
- `RELEASED`: liberación registrada.
- `ERROR ...`: solicitud inválida.

## Comportamiento de cada barco

Cada barco repite continuamente:

1. Navega durante un tiempo aleatorio.
2. Solicita acceso.
3. Si el atracadero está ocupado, espera y vuelve a consultar.
4. Cuando obtiene `GRANTED`, utiliza el atracadero durante un tiempo aleatorio.
5. Envía `RELEASE`.
6. Vuelve a navegar.

## Invariante de seguridad

La condición que debe mantenerse durante toda la ejecución es:

```text
cantidad_de_barcos_en_atracadero <= 1
```

La garantía está centralizada en el coordinador: solo concede `GRANTED` cuando no existe ocupante. Mientras exista un ocupante, todas las demás solicitudes reciben `WAIT`.

## Requisitos

- Docker Desktop o Docker Engine.
- Docker Compose v2 (`docker compose`).

No es necesario instalar GNAT en el equipo host porque las imágenes Docker instalan el compilador y compilan los programas durante el build.

## Ejecución

Desde esta carpeta:

```bash
docker compose up --build
```

O:

```bash
./ejecutar.sh
```

La ejecución es continua, tal como indica la consigna. Para detenerla presionar `Ctrl+C` y luego:

```bash
docker compose down
```

## Evidencia

Mientras los contenedores están o estuvieron ejecutándose:

```bash
./capturar_evidencia.sh
```

Esto crea `evidencia_ejecucion.txt` con los logs. Para la entrega se recomienda además realizar una captura de pantalla donde se vea que:

- varios barcos solicitan acceso;
- uno recibe autorización;
- los demás reciben espera;
- el barco autorizado libera el atracadero;
- posteriormente otro barco recibe autorización.

## Ejemplo esperado de ejecución

```text
barco-1       | Barco 1 solicita acceso al atracadero.
coordinador   | AUTORIZADO: Barco 1 puede utilizar el atracadero.
barco-1       | Barco 1 recibió autorización para atracar.
barco-2       | Barco 2 solicita acceso al atracadero.
coordinador   | EN ESPERA: Barco 2. Atracadero ocupado por Barco 1.
barco-3       | Barco 3 solicita acceso al atracadero.
coordinador   | EN ESPERA: Barco 3. Atracadero ocupado por Barco 1.
barco-1       | Barco 1 liberó el atracadero y vuelve a navegar.
coordinador   | LIBERADO: Barco 1 abandonó el atracadero.
barco-2       | Barco 2 solicita acceso al atracadero.
coordinador   | AUTORIZADO: Barco 2 puede utilizar el atracadero.
```

El ejemplo anterior ilustra el comportamiento esperado; la evidencia real debe generarse ejecutando la solución.

## Decisión de diseño

Se eligió una coordinación central mediante TCP porque:

- permite que cada barco sea un microservicio independiente;
- funciona naturalmente entre contenedores;
- centraliza la exclusión mutua sobre el recurso único;
- evita depender de memoria compartida entre procesos;
- es simple de explicar y verificar en la defensa.

La solución no garantiza un orden FIFO estricto entre barcos en espera, porque la consigna no lo exige. Un barco que recibe `WAIT` espera un segundo y vuelve a solicitar acceso.
