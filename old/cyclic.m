clc;clear all;close all;

COMPort = 'COM6';
baudRate = 9600;


if ~isempty(instrfind)
    fclose(instrfind);
    delete(instrfind);
end

% initialize com ports
s = serial(COMPort);
set(s, 'BaudRate', baudRate);
set(s,'DataBits',8);              %Chemyx RS232 serial port config
set(s,'Parity','none');
set(s,'StopBits',1);
set(s,'FlowControl','none');
set(s,'Terminator','CR/LF');
set(s,'Timeout',0.5);
fopen(s);


pump_number= 1;


diameter=20;

units=0;
% 0 = mL/min
% 1 = mL/hr
% 2 = uL/min
% 3 = uL/hr

volume=[10,-10];

% volume=[repmat(10,[1,10]),repmat(20,[1,10])];



time=[10,10];




tmp=[num2str(pump_number) ' set diameter ' num2str(diameter,'%.3f') ' '];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
disp(out)



tmp=[num2str(pump_number) ' set units ' num2str(units) sprintf('\r') ' '];
disp(tmp);
fprintf(s,tmp );
out = fscanf(s);
disp(out)


tmp=[num2str(pump_number) ' set volume ' num2str(volume,'%.3f,')];
tmp=tmp(1:end-1);
tmp=[tmp ' '];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
while ~isempty(out)
    disp(out)
    out = fscanf(s);
end


tmp=[num2str(pump_number) ' set time ' num2str(time,'%.3f,')];
tmp=tmp(1:end-1);
tmp=[tmp ' '];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
while ischar(tline)
    disp(out)
    out = fscanf(s);
end

% tmp= 'restart ';
% disp(tmp)
% fprintf(s,tmp);
% out = fscanf(s);
% disp(out)



% tmp= 'help ';
% disp(tmp)
% fprintf(s,tmp);
out = fscanf(s);
disp(out)

fclose(s);
delete(s);