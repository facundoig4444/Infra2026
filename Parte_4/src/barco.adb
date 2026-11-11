with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Environment_Variables;
with Ada.Numerics.Discrete_Random;
with GNAT.Sockets;               use GNAT.Sockets;

procedure Barco is

   function Get_Env (Name, Default : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      else
         return Default;
      end if;
   end Get_Env;

   subtype Tiempo_Aleatorio is Integer range 1 .. 4;
   package Random_Time is new Ada.Numerics.Discrete_Random (Tiempo_Aleatorio);
   Gen : Random_Time.Generator;

   Barco_Id : constant String := Get_Env ("BOAT_ID", "1");
   Host     : constant String := Get_Env ("COORDINATOR_HOST", "coordinador");
   Port_Num : constant Port_Type :=
     Port_Type'Value (Get_Env ("COORDINATOR_PORT", "5000"));

   function Resolver_Host return Inet_Addr_Type is
   begin
      --  Si se recibe una IP, se usa directamente. Si se recibe un nombre
      --  (por ejemplo "coordinador" en Docker Compose), se resuelve por DNS.
      begin
         return Inet_Addr (Host);
      exception
         when others =>
            declare
               Host_Info : constant Host_Entry_Type := Get_Host_By_Name (Host);
            begin
               return Addresses (Host_Info, 1);
            end;
      end;
   end Resolver_Host;

   function Enviar (Mensaje : String) return String is
      Socket  : Socket_Type;
      Address : Sock_Addr_Type;
      Channel : Stream_Access;
   begin
      Address.Addr := Resolver_Host;
      Address.Port := Port_Num;

      Create_Socket (Socket, Family_Inet, Socket_Stream);
      Connect_Socket (Socket, Address);
      Channel := Stream (Socket);

      String'Output (Channel, Mensaje);

      declare
         Respuesta : constant String := String'Input (Channel);
      begin
         Close_Socket (Socket);
         return Respuesta;
      end;

   exception
      when others =>
         begin
            Close_Socket (Socket);
         exception
            when others => null;
         end;
         return "CONNECTION_ERROR";
   end Enviar;

   Autorizado : Boolean;

begin
   Initialize;
   Random_Time.Reset (Gen);

   Put_Line ("========================================");
   Put_Line (" BARCO " & Barco_Id & " INICIADO");
   Put_Line (" Coordinador: " & Host & ":" &
             Port_Type'Image (Port_Num));
   Put_Line ("========================================");

   loop
      --  1. Permanecer navegando durante un tiempo aleatorio.
      declare
         Segundos : constant Integer := Integer (Random_Time.Random (Gen));
      begin
         Put_Line
           ("Barco " & Barco_Id & " navegando durante" &
            Integer'Image (Segundos) & " segundo(s)...");
         delay Duration (Segundos);
      end;

      --  2 y 3. Solicitar acceso y esperar autorización.
      Autorizado := False;

      while not Autorizado loop
         Put_Line ("Barco " & Barco_Id & " solicita acceso al atracadero.");

         declare
            Respuesta : constant String := Enviar ("REQUEST " & Barco_Id);
         begin
            if Respuesta = "GRANTED" then
               Autorizado := True;
               Put_Line
                 ("Barco " & Barco_Id &
                  " recibió autorización para atracar.");
            elsif Respuesta'Length >= 4
              and then Respuesta (Respuesta'First .. Respuesta'First + 3) = "WAIT"
            then
               Put_Line
                 ("Barco " & Barco_Id &
                  " debe esperar. Atracadero ocupado.");
               delay 1.0;
            else
               Put_Line
                 ("Barco " & Barco_Id &
                  " no pudo contactar al coordinador. Reintentando...");
               delay 1.0;
            end if;
         end;
      end loop;

      --  4. Utilizar el atracadero durante un tiempo aleatorio.
      declare
         Segundos : constant Integer := Integer (Random_Time.Random (Gen));
      begin
         Put_Line
           ("Barco " & Barco_Id & " utilizando el atracadero durante" &
            Integer'Image (Segundos) & " segundo(s).");
         delay Duration (Segundos);
      end;

      --  5. Informar que abandona el atracadero.
      declare
         Respuesta : constant String := Enviar ("RELEASE " & Barco_Id);
      begin
         if Respuesta = "RELEASED" then
            Put_Line
              ("Barco " & Barco_Id &
               " liberó el atracadero y vuelve a navegar.");
         else
            Put_Line
              ("Barco " & Barco_Id &
               " recibió una respuesta inesperada al liberar: " & Respuesta);
         end if;
      end;

      --  6 y 7 se cumplen al volver al comienzo del loop.
   end loop;

exception
   when others =>
      Put_Line ("Error fatal en Barco " & Barco_Id & ".");
      Finalize;
      raise;
end Barco;
