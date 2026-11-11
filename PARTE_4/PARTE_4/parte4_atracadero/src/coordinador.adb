with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Strings.Fixed;          use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;      use Ada.Strings.Unbounded;
with Ada.Environment_Variables;
with GNAT.Sockets;               use GNAT.Sockets;

procedure Coordinador is

   function Get_Env (Name, Default : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      else
         return Default;
      end if;
   end Get_Env;

   Port_Number : constant Port_Type :=
     Port_Type'Value (Get_Env ("COORDINATOR_PORT", "5000"));

   Server_Socket : Socket_Type;
   Client_Socket : Socket_Type;
   Server_Addr   : Sock_Addr_Type;
   Client_Addr   : Sock_Addr_Type;
   Channel       : Stream_Access;

   --  Vacío significa que el atracadero está libre.
   Ocupante : Unbounded_String := Null_Unbounded_String;

begin
   Initialize;

   Create_Socket (Server_Socket, Family_Inet, Socket_Stream);
   Set_Socket_Option
     (Server_Socket,
      Socket_Level,
      (Name => Reuse_Address, Enabled => True));

   Server_Addr.Addr := Inet_Addr ("0.0.0.0");
   Server_Addr.Port := Port_Number;

   Bind_Socket (Server_Socket, Server_Addr);
   Listen_Socket (Server_Socket);

   Put_Line ("========================================");
   Put_Line (" COORDINADOR DEL ATRACADERO");
   Put_Line (" Puerto: " & Port_Type'Image (Port_Number));
   Put_Line ("========================================");
   Put_Line ("Esperando solicitudes...");

   loop
      Accept_Socket (Server_Socket, Client_Socket, Client_Addr);
      Channel := Stream (Client_Socket);

      declare
         Request : constant String := String'Input (Channel);
      begin
         if Request'Length > 8
           and then Request (Request'First .. Request'First + 7) = "REQUEST "
         then
            declare
               Barco : constant String :=
                 Request (Request'First + 8 .. Request'Last);
            begin
               Put_Line ("Solicitud recibida de Barco " & Barco & ".");

               if Length (Ocupante) = 0 then
                  Ocupante := To_Unbounded_String (Barco);
                  String'Output (Channel, "GRANTED");
                  Put_Line
                    ("AUTORIZADO: Barco " & Barco &
                     " puede utilizar el atracadero.");
               else
                  String'Output
                    (Channel, "WAIT " & To_String (Ocupante));
                  Put_Line
                    ("EN ESPERA: Barco " & Barco &
                     ". Atracadero ocupado por Barco " &
                     To_String (Ocupante) & ".");
               end if;
            end;

         elsif Request'Length > 8
           and then Request (Request'First .. Request'First + 7) = "RELEASE "
         then
            declare
               Barco : constant String :=
                 Request (Request'First + 8 .. Request'Last);
            begin
               if To_String (Ocupante) = Barco then
                  Ocupante := Null_Unbounded_String;
                  String'Output (Channel, "RELEASED");
                  Put_Line
                    ("LIBERADO: Barco " & Barco &
                     " abandonó el atracadero.");
               else
                  String'Output (Channel, "ERROR NOT_OWNER");
                  Put_Line
                    ("AVISO: Barco " & Barco &
                     " intentó liberar un atracadero que no ocupa.");
               end if;
            end;

         elsif Request = "STATUS" then
            if Length (Ocupante) = 0 then
               String'Output (Channel, "FREE");
            else
               String'Output
                 (Channel, "BUSY " & To_String (Ocupante));
            end if;

         else
            String'Output (Channel, "ERROR UNKNOWN_COMMAND");
            Put_Line ("Comando desconocido: " & Request);
         end if;
      exception
         when others =>
            Put_Line ("Error procesando una solicitud.");
      end;

      Close_Socket (Client_Socket);
   end loop;

exception
   when others =>
      Put_Line ("Error fatal en el coordinador.");
      Close_Socket (Server_Socket);
      Finalize;
      raise;
end Coordinador;
