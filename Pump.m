classdef Pump
   properties
      s
      COMPort
      baudRate
      pumpNumber
      diameter
   end

   methods
       
       function obj = Pump(COMPort,baudRate,pumpNumber,diameter)
           obj.COMPort = COMPort;
           obj.baudRate=baudRate;
           obj.pumpNumber=pumpNumber;
           if ~isempty(instrfind)
                fclose(instrfind);
                delete(instrfind);
           end
           
            obj.s = serial(obj.COMPort);
           
            set(obj.s, 'BaudRate', obj.baudRate);
            set(obj.s,'DataBits',8);              %Chemyx RS232 serial port config
            set(obj.s,'Parity','none');
            set(obj.s,'StopBits',1);
            set(obj.s,'FlowControl','none');
            set(obj.s,'Terminator','CR/LF');
            set(obj.s,'Timeout',0.5);
            fopen(obj.s);
            
            
            obj.diameter=diameter;
            
            tmp=[num2str(obj.pumpNumber) ' set diameter ' num2str(diameter,'%.3f') ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
             while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 

            
           
       end
       
       
       function set_volume(obj,data)
           tmp=[num2str(obj.pumpNumber) ' set volume ' num2str(data,'%.3f,')];
            tmp=tmp(1:end-1);
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
           
       end
       
       
       function set_units(obj,data)
           
           if strcmp(data,'mL/min')
               data=0;
           elseif strcmp(data,'mL/hr')
               data=1;
           elseif strcmp(data,'uL/min')
               data=2;
           elseif strcmp(data,'uL/hr')
               data=3;
           end
           
           
            tmp=[num2str(obj.pumpNumber) ' set units ' num2str(data)];
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
           
       end
       
       

       function set_time(obj,data)
           tmp=[num2str(obj.pumpNumber) ' set time ' num2str(data,'%.3f,')];
            tmp=tmp(1:end-1);
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
           
       end
       
       function set_rate(obj,data)
            tmp=[num2str(obj.pumpNumber) ' set rate ' num2str(data,'%.3f,')];
            tmp=tmp(1:end-1);
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
           
       end
       
       
       function set_delay(obj,data)
            tmp=[num2str(obj.pumpNumber) ' set delay ' num2str(data,'%.3f,')];
            tmp=tmp(1:end-1);
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
           
       end
       
  
       
       function start(obj)
          tmp=[num2str(obj.pumpNumber) ' start ' num2str(1)];
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
       end 
       
%        function stop(obj)
%           tmp=[num2str(obj.pumpNumber) 'stop'];
%             tmp=[tmp ' '];
%             disp(tmp);
%             fprintf(obj.s, tmp);
%             out = fscanf(obj.s);
%             while ~isempty(out)
%                 disp(out)
%                 out = fscanf(obj.s);
%             end 
%        end 
       
       
       function stop(obj)
          tmp=[num2str(obj.pumpNumber) ' pause'];
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
       end 
       
       
       function help(obj)
          tmp=['help'];
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            while ~isempty(out)
                disp(out)
                out = fscanf(obj.s);
            end 
       end 
       
       function [limits]=limits(obj)
          tmp=[num2str(obj.pumpNumber) ' read limit parameter'];
            tmp=[tmp ' '];
            disp(tmp);
            fprintf(obj.s, tmp);
            out = fscanf(obj.s);
            k=0;
            while ~isempty(out)
                k=k+1;
                if k ==2
                    limits=out;
                end
                disp(out)
                out = fscanf(obj.s);
            end 
       end 
       
       function close(obj)
          fclose(obj.s);
          delete(obj.s);
       end 
       
   end
end