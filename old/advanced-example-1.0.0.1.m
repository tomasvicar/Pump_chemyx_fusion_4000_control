COMPort = 'COM3';
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

diameter = input('Enter the syringe diameter. ');

% set inner diameter
fprintf(s, sprintf('set diameter %.3f ', diameter));
%out = fscanf(s);


volume = input('Enter the volumes to pump separated by spaces. ', 's');
tmp = textscan(volume, '%f');
volStr = sprintf('%.5f,', tmp{1});

% set volume
% fprintf(s, sprintf('set volume %.5f, %.5f', volume1, volume2));
fprintf(s, horzcat('set volume ', volStr));
%out = fscanf(s);

rate = input('Enter the rates to pump separated by spaces. ', 's');
tmp = textscan(rate, '%f');
rateStr = sprintf('%.5f,', tmp{1});

% set rate
% fprintf(s, sprintf('set rate %.5f, %.5f', rate1, rate2));
fprintf(s, horzcat('set rate ', rateStr));
%out = fscanf(s);

delay = input('Enter the delays before each step separated by spaces. ', 's');
tmp = textscan(delay, '%f');
delayStr = sprintf('%.5f,', tmp{1});

% set delay
% fprintf(s, sprintf('set delay %.5f, %.5f', delay1, delay2));
fprintf(s, horzcat('set delay ', delayStr));
%out = fscanf(s);

input('Press any key then hit Enter to start', 's');

% start pump
% pump should start moving now
fprintf(s, 'start');
%out = fscanf(s);

mssg = 'Press any key then hit Enter to pause. ';
input(mssg, 's');

% pause pump
fprintf(s, 'pause');
%out = fscanf(s);

mssg = 'Press any key then hit Enter to resume. ';
input(mssg, 's');

% restart the pump
fprintf(s, 'start');
%out = fscanf(s);

mssg = 'Press any key then hit Enter to stop. ';
input(mssg, 's');

% stop pump
fprintf(s, 'stop');
%out = fscanf(s);

% close com ports
fclose(s);
delete(s);
