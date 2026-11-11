-- Torneo de Padel
-- 16 parejas juegan 8 partidos, pero hay solamente 3 canchas.
-- El Coordinador es una task que guarda los partidos pendientes.
-- Cada cancha es una task que le pide partidos mediante citas.

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Discrete_Random;

procedure Torneo_Padel is

   Cantidad_Partidos : constant Integer := 8;
   Cantidad_Canchas  : constant Integer := 3;

   -- genero numeros aleatorios en este rango: los segundos que dura un partido
   type randRange is new Integer range 1 .. 4;
   package Rand_Int is new Ada.Numerics.Discrete_Random (randRange);
   use Rand_Int;

   -- Arreglo para guardar las parejas de cada partido
   type Lista_Parejas is array (1 .. Cantidad_Partidos) of Integer;

   Task Coordinador is
      -- Hay = False significa "no quedan partidos, podes terminar"
      Entry Pedir_Partido (NroCancha  : in  Integer;
                           NroPartido : out Integer;
                           Hay        : out Boolean);

      Entry Informar_Resultado (NroCancha  : in Integer;
                                NroPartido : in Integer;
                                Ganador    : in Integer);
   End Coordinador;

   Task type Cancha is
      Entry Iniciar (Nro : in Integer);  -- para avisarle su numero
   End Cancha;

   -- Las 3 canchas
   Canchas : array (1 .. Cantidad_Canchas) of Cancha;

   Task body Coordinador is
      -- Los 8 partidos estan definidos desde el comienzo
      Pareja_A : Lista_Parejas := (1, 3, 5, 7,  9, 11, 13, 15);
      Pareja_B : Lista_Parejas := (2, 4, 6, 8, 10, 12, 14, 16);

      Proximo          : Integer := 1;  -- proximo partido a asignar
      Terminados       : Integer := 0;  -- resultados que ya recibi
      Canchas_Avisadas : Integer := 0;  -- canchas a las que ya les dije que terminen
   begin
      -- Sigo atendiendo citas hasta haber avisado a las 3 canchas
      while Canchas_Avisadas < Cantidad_Canchas loop

         select
            -- Una cancha me pide un partido
            accept Pedir_Partido (NroCancha  : in  Integer;
                                  NroPartido : out Integer;
                                  Hay        : out Boolean)
            do
               if Proximo <= Cantidad_Partidos then
                  NroPartido := Proximo;
                  Hay        := True;

                  New_Line;
                  Put_Line ("Coordinador:");
                  Put_Line ("Partido" & Proximo'Image &
                            " asignado a Cancha" & NroCancha'Image & ".");
                  Put_Line ("Pareja" & Pareja_A (Proximo)'Image &
                            " vs Pareja" & Pareja_B (Proximo)'Image & ".");

                  Proximo := Proximo + 1;
               else
                  NroPartido := 0;
                  Hay        := False;

                  New_Line;
                  Put_Line ("Coordinador:");
                  Put_Line ("No quedan partidos. Cancha" &
                            NroCancha'Image & " puede retirarse.");

                  Canchas_Avisadas := Canchas_Avisadas + 1;
               end if;
            end Pedir_Partido;

         or
            -- Una cancha me informa el resultado de su partido
            accept Informar_Resultado (NroCancha  : in Integer;
                                       NroPartido : in Integer;
                                       Ganador    : in Integer)
            do
               New_Line;
               Put_Line ("Coordinador recibio el resultado de Cancha" &
                         NroCancha'Image & ".");
               Put_Line ("Partido" & NroPartido'Image &
                         " - Ganador: Pareja" & Ganador'Image & ".");

               Terminados := Terminados + 1;
            end Informar_Resultado;

         end select;
      end loop;

      New_Line;
      Put_Line ("Todos los partidos han finalizado.");
      -- Terminados vale 8 aca: es la evidencia de que llegaron los 8 resultados
      Put_Line ("Torneo terminado.");
   end Coordinador;

   Task body Cancha is
      gen        : Generator;
      MiNumero   : Integer;
      NroPartido : Integer;
      Hay        : Boolean;
      Ganador    : Integer;
   begin
      -- Primero espero que me digan que numero de cancha soy
      accept Iniciar (Nro : in Integer) do
         MiNumero := Nro;
      end Iniciar;

      -- Cada cancha tiene su propio generador
      reset (gen, MiNumero);

      loop
         New_Line;
         Put_Line ("Cancha" & MiNumero'Image & " solicita un partido.");

         Coordinador.Pedir_Partido (MiNumero, NroPartido, Hay);
         exit when not Hay;

         New_Line;
         Put_Line ("Cancha" & MiNumero'Image & " esta disputando el partido" &
                   NroPartido'Image & "...");

         -- El partido dura 1, 2, 3 o 4 segundos, sorteados con igual probabilidad.
         -- El delay va afuera de la cita, asi el Coordinador queda libre
         -- para atender a las otras canchas mientras esta se juega.
         delay Duration (random (gen));

         -- Gana la primera pareja si sale 1 o 2, la segunda si sale 3 o 4
         if random (gen) <= 2 then
            Ganador := 2 * NroPartido - 1;
         else
            Ganador := 2 * NroPartido;
         end if;

         New_Line;
         Put_Line ("Cancha" & MiNumero'Image & " finalizo el partido" &
                   NroPartido'Image & ".");
         Put_Line ("Ganador: Pareja" & Ganador'Image & ".");

         Coordinador.Informar_Resultado (MiNumero, NroPartido, Ganador);
      end loop;

      -- La cancha termina sin imprimir nada: el Coordinador ya anuncio su retiro
      -- dentro de la cita. Asi el ultimo mensaje del programa es siempre el suyo.
   end Cancha;

begin
   Put_Line ("=== Torneo de Padel ===");

   -- Le doy su numero a cada cancha para que empiece a trabajar
   For I in 1 .. Cantidad_Canchas loop
      Canchas (I).Iniciar (I);
   end loop;
end Torneo_Padel;
