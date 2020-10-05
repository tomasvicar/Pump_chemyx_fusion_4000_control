clc;clear all;close all;

addpath('C:\Users\tomas\Desktop\test_hadicek')


table=readtable('5_spravnyprumer.csv');

y=table.FlowLinearized_ml_min_;
x=table.RelativeTime_s_;

xx=zeros(1,length(x));
for k=1:length(x)
    tmp=str2num(replace(replace(replace(x{k},',','.'),'Â',''),' ',''));
    if isempty(tmp)
        tmp=nan;
    end
    xx(k)= tmp;
end




yy=zeros(1,length(x));
for k=1:length(y)
    tmp=str2num(replace(y{k},',','.'));
    if isempty(tmp)
        tmp=nan;
    end
    yy(k)= tmp;
end


plot(xx-xx(1),yy*1000)
hold on

rate=[1,2,4,8,16,32,64,128]*12.98;
step_time=60;
delay_time=60;


time=[];
values=[];
for k=1:length(rate)
    
    time=[time,(1:(delay_time+step_time))+(k-1)*(delay_time+step_time)];
    values=[values,zeros(1,delay_time),rate(k)*ones(1,step_time)];


end

plot(time,values)








