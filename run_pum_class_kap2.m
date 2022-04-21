clc;clear all force;close all;

COMPort = 'COM3';
baudRate = 115200;
pump_num=2;
% diameter=20;
diameter=19;
% diameter=15;

pump=Pump(COMPort,baudRate,pump_num,diameter);

pump.set_units('uL/min')



% pump.set_volume([-5,5,-5])
% % pump.set_time([10,10,10])
% 
% pump.set_rate([10,10,10])
% 
% pump.set_delay([10,10,10])
% 
% 
% 
% 
% 
% pump.start(1)
% 
% pump.stop()
% k=0.5;
% rates=[linspace(10^k,400^k,10).^(1/k)]*12.98;

% rates=[50,50,50,100,100,100]*12.98;

% rates = repmat(rates,[1,3]);

rates=[50,50]*12.98;
% rates=[500,500]*12.98;

% step_time=10;
% delay_time=10;

step_time=600;
delay_time=0;

delays=repmat(delay_time,[1,length(rates)]);
times=repmat(step_time,[1,length(rates)]);


% rates = [5*12.98,rates];
% delays = [5,delays];
% times = [60,times];

% rates=[50,50]*12.98;
% delays =[0,0];
% times=[120,120];


volumes=times.*rates/60;

disp(sum(volumes))

pump.set_volume(volumes)
pump.set_rate(rates)
% pump.set_time(times)
pump.set_delay(delays)


% pump.stop()
% pump.start()
% pump.close()
% pump.help()

% pump.limits()