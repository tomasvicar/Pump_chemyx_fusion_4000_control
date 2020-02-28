clc;clear all;close all;

COMPort = 'COM6';
baudRate = 9600;


% delay1 = input('Enter a delay time in minutes before starting to pump. ');
% volume1 = input('Enter the first volume to pump. ');
% rate1 = input('Enter the rate to pump the first volume. ');
% delay2 = input('Enter a delay time in minutes before starting to pump the second volume. ');
% volume2 = input('Enter the second volume to pump. ');
% rate2 = input('Enter the rate to pump the second volume. ');

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


diameter=20;

units=0;
% 0 = mL/min
% 1 = mL/hr
% 2 = ?L/min
% 3 = ?L/hr

% volume=[60,40,30];
volume=60;

% time=[10,20,30];
time=5;

% rate=[1,0.5,0.2];
rate=1;


% delay=[0.5,1,1];
delay=0.5;


tmp=['set diameter ' num2str(diameter,'%.3f')];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
disp(out)

tmp=['set units ' num2str(units) sprintf('\r')];
disp(tmp);
fprintf(s,tmp );
out = fscanf(s);
disp(out)

tmp=['set volume ' num2str(volume,'%.3f,')];
tmp=tmp(1:end-1);
tmp=[tmp sprintf('\r')];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
disp(out)

tmp=['set time ' num2str(time,'%.3f,')];
tmp=tmp(1:end-1);
tmp=[tmp sprintf('\r')];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
disp(out)

tmp=['set rate ' num2str(rate,'%.3f,')];
tmp=tmp(1:end-1);
tmp=[tmp sprintf('\r')];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
disp(out)

tmp=['set delay ' num2str(delay,'%.3f,')];
tmp=tmp(1:end-1);
tmp=[tmp sprintf('\r')];
disp(tmp);
fprintf(s, tmp);
out = fscanf(s);
disp(out)




tmp= '1 start 1';
disp(tmp)
fprintf(s,tmp);
out = fscanf(s);
disp(out)






% fprintf(s, 'help');
% out = fscanf(s);
% disp(out)

% fprintf(s, 'status');
% out = fscanf(s);
% disp(out)


% close com ports
fclose(s);
delete(s);