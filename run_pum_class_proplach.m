clc;clear all force;close all;

COMPort = 'COM6';
baudRate = 115200;
pump_num=1;
% diameter=20;
diameter=17;

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

% rates=[50,100]*12.98;




delays=repmat(delay_time,[1,length(rates)]);

% rates=[128,128,128]*12.98;

rates=[10]*12.98;
% rates=[5:5:50]*12.98;
% rates=[10:10:100]*12.98;
% rates=[20:20:400]*12.98;
% rates=[5,10,15,20,25,30,35,40,45,50]*12.98;
% k=0.5;
% rates=linspace(1^k,32^k,10).^(1/k);
% rates=linspace(1^k,64^k,10).^(1/k);

% rates=[1,64,128]*12.98;
% step_time=0;

% step_time=60;
% delay_time=0;

% delay_time=60;

delay_time=0;
step_time=180;

times=repmat(step_time,[1,length(rates)]);


% delays=repmat(delay_time,[1,length(rates)]);

% k=0.5;
% linspace(1^k,32^k,10).^(1/k);


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