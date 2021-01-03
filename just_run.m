clc;clear all force;close all;

COMPort = 'COM5';
baudRate = 115200;
pump_num=1;
diameter=20;
% diameter=17;

pump=Pump(COMPort,baudRate,pump_num,diameter);


% pump.stop()
pump.start()
% pump.close()
% pump.help()