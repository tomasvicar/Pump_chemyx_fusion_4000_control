clc;clear all;close all;

% addpath('C:\Users\tomas\Desktop\test_hadicek')
% addpath('C:\Users\tomas\Desktop\test_hadicek')


% "hadicky\merreni_hadicek\2.csv"

% files = 

xxx = {"hadicky\merreni_hadicek\1.csv",...
    "hadicky\merreni_hadicek\4.csv","hadicky\tvrda_hadicka_nove_spojky2.csv","hadicky\tvrda_hadicka_nove_spojky_sklenena.csv",...
    "hadicky\hadicky_nove.csv"};

leg = {};
for xxx_num = 1:length(xxx)
    tmp = split(xxx{xxx_num});
    leg =[leg tmp{end}];
    
    table = readtable(xxx{xxx_num});


    y=table.FlowLinearized_ml_min_;
    x=table.RelativeTime_s_;

    xx=zeros(1,length(x));
    for k=1:length(x)
        tmp=str2num(replace(replace(replace(x{k},',','.'),'�',''),'�',''));
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

    yy = medfilt1(yy,51);
    yy = gaussfilt1(yy',5)';
    
    if xxx_num>3
        yy = yy*1.3;
    end
    
    
    
    plot(xx-xx(1),yy*1000,'LineWidth',3)
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
    
%     print([num2str(xxx_num) 'cary'],'-dsvg')

    % plot(time,values)

end

plot([0 662 662 722 722 780],[0 0 400 400 0 0],'LineWidth',3)

xlim([650 780])


leg = {...
    'HSW HENKE-JECT plastic 60ml + Ibidi silicon (1.6 mm / 0.8 mm)'
    'HSW HENKE-JECT plastic 60ml + Ibidi silicon (0.8 mm / 2.8 mm)'
    'HSW HENKE-JECT plastic 10ml + Ibidi silicon (0.8 mm / 2.8 mm)'
    'Fortuna Optima glass 20ml + Ibidi silicon (0.8 mm / 2.8 mm)'
    'Fortuna Optima glass 20ml + Darwin Microfluidics PTFE (1/16" / 1/32")'
    'Optimal signal'
    };

xticks([650:40:770])
xticklabels({'0','40','80','120'})
xlabel('Time (s)')
ylabel('Flow rate (\mu l / min)')
% leg = {}

legend(leg)

set(gca,'FontSize',15)
set(gca,'FontWeight','bold')
set(gca,'linewidth',2)
% print(['cary_all'],'-dsvg')
% print(['cary_all'],'-dpng','-r250')



