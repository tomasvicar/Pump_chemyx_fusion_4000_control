clc;clear all;close all;

COMPort = 'COM4';
baudRate = 115200;
pump_num=1;
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



% rates=[1,2,4,8,16,32,64,128]*12.98;
rates=[32,64,128]*12.98;
step_time=60;
delay_time=0;


times=repmat(step_time,[1,length(rates)]);
delays=repmat(delay_time,[1,length(rates)]);




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