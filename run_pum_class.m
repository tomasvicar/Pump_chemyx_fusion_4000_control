clc;clear all;close all;

COMPort = 'COM3';
baudRate = 115200;
pump_num=1;
diameter=27;


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


shear_stres=64*[1,1,1,1,1];

% shear_stres=32*[1,-1,1,-1,1,-1];

rate_values=shear_stres*(12.98);

replicas=1;
step_time=40;
delay_time=40;
% % rate_values=[0.5,1,2,4,8];
% rate_values=[8,12,16,20,24];

rates=[];
for k=1:length(rate_values)
    rates=[rates,repmat(rate_values(k),[1,replicas])];
end
times=repmat(step_time,[1,length(rates)]);
delays=repmat(delay_time,[1,length(rates)]);


% rates=[2 rates];
% times=[20 times];
% delays=[0,delays];


volumes=times.*rates/60;

disp(sum(volumes))

pump.set_volume(volumes)
pump.set_rate(rates)
% pump.set_time(times)
pump.set_delay(delays)


pump.close()

