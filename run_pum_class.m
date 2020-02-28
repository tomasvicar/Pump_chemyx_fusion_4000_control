clc;clear all;close all;

COMPort = 'COM6';
baudRate = 9600;
pump_num=1;
diameter=20;


pump=Pump(COMPort,baudRate,pump_num,diameter);

pump.set_units('mL/min')



pump.set_volume([-5,5,-5])
% pump.set_time([10,10,10])

pump.set_rate([10,10,10])

pump.set_delay([10,10,10])





pump.start(1)

pump.stop()





pump.close()

