%Script:                pump_gui2.m
%Version:               0.2 REL
%
%Date:                  11Sep2016
%Company:               Chemyx, Inc.
%
%Software Developer:    HTCV Information, LLC
%                       htcveng@gmail.com
%Author:                William Copeland
%
%Description: Advanced program with GUI to control and retrieve status of
%  Chemyx Syringe Pump including multi-step mode. Communicates through the 
%  RS232 serial interface.
%  Changed infuse/withdraw to step-wise parameter, enhanced button press
%    handling to reduce delay, added volume/rate limit checks. (ver0.2).

function varargout = pump_gui2(varargin)

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pump_gui2_OpeningFcn, ...
                   'gui_OutputFcn',  @pump_gui2_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before pump_gui2 is made visible.
function pump_gui2_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for pump_gui2
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

%add new variable so UIs can access
                 %create reference vector for RS232 receive line parsing
handles.digNperiod =['0' '1' '2' '3' '4' '5' '6' '7' '8' '9' '.'];
handles.digNperiodNneg =['0' '1' '2' '3' '4' '5' '6' '7' '8' '9' '.' '-'];
handles.digNperiodNspace =['0' '1' '2' '3' '4' '5' '6' '7' '8' '9' '.' ' '];

%set all display defaults
set(handles.PumpStatDisp,'String','Unknown');
set(handles.ElapTmDisp,'String','Unknown');
set(handles.DispensVolDisp,'String','Unknown');
set(handles.DLComPopup,'String',['COM3';'COM1']);
set(handles.TmUnitDisp,'String','HH:MM:SS');
set(handles.RateUnitPopUp,'String',['ml / min';'ml / hr ';'ul / min';'ul / hr ']);
set(handles.RateUnitPopUp,'Value',1.0);
set(handles.BaudPopUp,'String',['38400';'9600 ']);
set(handles.BaudPopUp,'Value',1.0);
nsteps=1;                                                   %for steps
ns_str=num2str(nsteps);
if length(ns_str)==1
  fns_str=['0',ns_str];  %add 0 padding
else
  fns_str=ns_str;
end;
set(handles.NumStepDisp,'String',ns_str);   
set(handles.CurrStepPopUp,'String',fns_str);
set(handles.CurrStepPopUp,'Value',nsteps);
set(handles.DiamDisp,'String','0.0');

%update related fields
rateunitsel = get(handles.RateUnitPopUp,'Value');
if ((rateunitsel == 1.0) | (rateunitsel == 2.0))
  set(handles.VolUnitDisp,'String','ml');
elseif ((rateunitsel == 3.0) | (rateunitsel == 4.0))
  set(handles.VolUnitDisp,'String','ul');
else
  display('ERROR: Invalid rate units.');
end;
rateunitlist_strvec = get(handles.RateUnitPopUp,'String');
set(handles.RateUnitDisp,'String',rateunitlist_strvec((rateunitsel),:));

com_strmx = get(handles.DLComPopup,'String');   %read selected com port
strmx_idx = get(handles.DLComPopup,'Value');
selcom_str = com_strmx(strmx_idx,:);

%check available ports, validate versus selected, and potentially reassign 
%  GUI default port
availports=getAvailableComPort();

if (isempty(availports{1}))
  display('ERROR: no COM ports currently available.');
end;

%compare selected port to available ports
[validchk] = validport(selcom_str,availports);

if (find(validchk)==1)    %see if first port available
  handles.s = serial(com_strmx(strmx_idx,:));   %if so, use it
else      %otherwise, switch ports and check this one as well
  set(handles.DLComPopup,'Value',2.0);
  
  com_strmx = get(handles.DLComPopup,'String');   %read selected com port
  strmx_idx = get(handles.DLComPopup,'Value');
  selcom_str = com_strmx(strmx_idx,:);
  
  [validchk] = validport(selcom_str,availports);
  
  if (find(validchk)==1)   %check second port availability
    handles.s = serial(com_strmx(strmx_idx,:));   %if so, use it
  else
    display('ERROR: Neither COM1 nor COM3 are available.');
  end;
end;

baud_strmx = get(handles.BaudPopUp,'String');  %get baud rate
baud_idx = get(handles.BaudPopUp,'Value');
baud_str = baud_strmx(baud_idx,:);
baud_dec = str2num(baud_str);
set(handles.s,'BaudRate',baud_dec);      

set(handles.s,'DataBits',8);              %Chemyx RS232 serial port config
set(handles.s,'Parity','none');
set(handles.s,'StopBits',1);
set(handles.s,'FlowControl','none');
set(handles.s,'Terminator','CR/LF');
set(handles.s,'Timeout',0.5);

fopen(handles.s);                     %open serial port


%create and initialize shared data structure
data = struct('ceaseupd_flg',0,'oneupdate_flg',0,...
              'stoponce_flg',1,'onetimeunitupd_flg',0,...
              'resetlock_flg',0,'cleanupobj',cleanup(handles.s),...
              'stopbutpress_flg',0,...
              'oneORmorebutpress_flg',0,'DLsemaphore_flg',0,...
              'startbutpress_flg',0,'pausebutpress_flg',0,...
              'quitbutpress_flg',0,'killGUI_flg',0,...
              'step_cellarr',stepdata(nsteps),...
              'pausetm',0.04,'delay_val',0,...
              'volmax',100,'volmin',0,...
              'ratemax',200,'ratemin',0);
    %ceaseupd_flg            stop display update flag
    %oneupdate_flg          one last update flag
    %stoponce_flg           to ensure only stop once
    %onetimeunitupd_flg     update volume units once per start press flag
    %resetlock_flg          reset button lock flag
    %cleanupobj             robust GUI clean-up mechanism
    %oneORmorebutpress_flg  one or more buttons pressed flag
    %DLsemaphore_flg        serial data link semaphore flag
    %startbutpress_flg      start button pressed flag
    %stopbutpress_flg       stop button pressed flag
    %pausebutpress_flg      pause button pressed flag
    %quitbutpress_flg       quit button pressed flag
    %killGUI_flg            kill GUI flag
    %step_cellarr           step data storage object
    %pausetm                pause time
    %delay_val              min, pump delay value for basic mode only
    %volmax                 maximum volume limit
    %volmin                 minimum volume limit
    %ratemax                maximum rate limit
    %ratemin                minimum rate limit
    
set(handles.figure1,'UserData',data);
data = get(handles.figure1,'UserData');

%initialize step cell array data
%elem#    description
%  1      volume
%  2      rate
%  3      delay min
%  4      delay sec
for ci=1:nsteps
  data.step_cellarr.stepidx{ci} = cell(1,4);
  data.step_cellarr.stepidx{ci}{1}='0.0';
  data.step_cellarr.stepidx{ci}{2}='0.0';
  data.step_cellarr.stepidx{ci}{3}='0';
  data.step_cellarr.stepidx{ci}{4}='0';
end;

set(handles.figure1,'UserData',data);
data = get(handles.figure1,'UserData');

%initialize step parameter panel and current step popup values
set(handles.VolDisp,'String',data.step_cellarr.stepidx{1}{1});
set(handles.RateDisp,'String',data.step_cellarr.stepidx{1}{2});
set(handles.DelayMinDisp,'String',data.step_cellarr.stepidx{1}{3});
set(handles.DelaySecDisp,'String',data.step_cellarr.stepidx{1}{4});

warnID='MATLAB:serial:fscanf:unsuccessfulRead';
warning('off',warnID);

set(handles.DLPanel,'FontWeight','bold');
set(handles.PumpModePanel,'FontWeight','bold');
set(handles.MSPanel,'FontWeight','bold');
set(handles.StatPanel,'FontWeight','bold');

guidata(hObject, handles);              %save final changes to structure

% --- Outputs from this function are returned to the command line.
function varargout = pump_gui2_OutputFcn(hObject, eventdata, handles) 
% Get default command line output from handles structure
varargout{1} = handles.output;

data = get(handles.figure1,'UserData');

resumeupd_flg = 0;                     %reset flag
set(handles.figure1,'UserData',data);

%check pump status to determine proper settings
%  recall that muli-step mode is the GUI default
fprintf(handles.s,'status');     
pause(data.pausetm);                     
out = fscanf(handles.s);
while (isempty(findstr('>',out)))
  if (isempty(out))   
    break;               
  end
  out_num = str2num(out(1));
  if (out_num==1)     %if pump already running (=1), 
                      %  assume in multi-step mode by default
    data.stoponce_flg = 0;    %reset stop button flag
    resumeupd_flg = 1;   %set flag to resume updating
    data.onetimeunitupd_flg = 1;    %update units
    data.ceaseupd_flg = 0;     %reset flag for continuous updates
    
    %if already running then disable pump mode radio buttons and
    %  start button
    keybutthnds = [handles.SnglStepRadioBut,handles.MultStepRadioBut,...
                   handles.StrtBut,handles.SendStepsBut,...
                   handles.ApplyParamBut,...
                   handles.AddBefBut,handles.AddAftBut,handles.RemStepBut];
    set(keybutthnds,'Enable','off');
    
  elseif (out_num == 0) | (out_num == 3)   
        %=0 pump stopped (basic), =3 pump stopped / delayed
        %  multi-step assumed by default
    keybutthnds = [handles.StrtBut,handles.PausBut,handles.StopBut];
    set(keybutthnds,'Enable','off'); 
    
    data.ceaseupd_flg = 1;    %don't resume cont upd
    resumeupd_flg = 1;        %set flag to resume updating
    data.onetimeunitupd_flg = 1;    %update units
    data.oneupdate_flg = 2;         %allow one last update flag
    
  elseif (out_num == 2)   %=2 pump paused, multi-step mode
                          %  assumed by default
    keybutthnds = [handles.PausBut,handles.SendStepsBut,...
                   handles.ApplyParamBut,...
                   handles.AddBefBut,handles.AddAftBut,handles.RemStepBut];
    set(keybutthnds,'Enable','off');
    
    data.ceaseupd_flg = 1;    %don't resume cont upd
    data.stoponce_flg = 0;    %reset stop button flag
    resumeupd_flg = 1;        %set flag to resume updating
    data.onetimeunitupd_flg = 1;    %update units
    data.oneupdate_flg = 2;         %allow one last update flag
  end
  if ((out_num==1) | (out_num==2))  %enable reset button lock flag if pump
    data.resetlock_flg = 1;         %  running (=1) or paused (=2)
  end
  
  out = fscanf(handles.s);
end  

set(handles.figure1,'UserData',data);

data = get(handles.figure1,'UserData');     
if (resumeupd_flg == 1)        %if pump running already, resume upds
  set(handles.figure1,'UserData',data);
  pump_gui2('UpdBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
            %resume updates
end;
            
% --- Executes on button press in StrtBut.
function StrtBut_Callback(hObject, eventdata, handles)

if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');   %update shared data
    
  chkbutenb_str = get(handles.StrtBut,'Enable');
  
  if (data.DLsemaphore_flg == 0)   %see if DL available
    %if DL available then do regular processing
    pump_gui2('StrtBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  elseif (strcmp(chkbutenb_str,'on') == 1)
      %otherwise capture button press for later processing, but only
      %  if start button is active
    data.startbutpress_flg = 1;       %set start button pressed flag &
    data.oneORmorebutpress_flg = 1;   %one or more buttons pressed flag
    set(handles.figure1,'UserData',data);
    
    data = get(handles.figure1,'UserData');
  end;
end;

function StrtBut_ButtonDownFcn(hObject, eventdata, handles)
chkbutenb_str = get(handles.StrtBut,'Enable');

[retstat] = chkNterm_link(handles.s,handles.figure1);
if ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 1))  
        %if no DL OR button disabled issues
  data = get(handles.figure1,'UserData');    %get shared data

  data.ceaseupd_flg = 0;                      %(re-)activate status updating
  if data.oneupdate_flg ~= 2
    data.oneupdate_flg = 0;                   %reset one-time update flag
  end;
  data.stoponce_flg = 0;                      %clear stop once flag
  data.onetimeunitupd_flg = 1;                %one time vol unit update
  data.resetlock_flg = 1;                     %enable reset button lock
  set(handles.figure1,'UserData',data);

  keybutthnds = [handles.SnglStepRadioBut,handles.MultStepRadioBut,...
      handles.SendStepsBut,handles.StrtBut,handles.ApplyParamBut,...
      handles.AddBefBut,handles.AddAftBut,handles.RemStepBut];
  set(keybutthnds,'Enable','off');
  keybutthnds2 = [handles.PausBut,handles.StopBut];
  set(keybutthnds2,'Enable','on');
  
  data = get(handles.figure1,'UserData');

  out = fscanf(handles.s);
  while ~isempty(out) 
    out = fscanf(handles.s);
  end
  
  fprintf(handles.s,'start');     %send command
  if get(handles.MultStepRadioBut,'Value')   %use step#1 multi-step delay
    %get step#1 delay, if any
    delaymin2=str2num(data.step_cellarr.stepidx{1}{3});
    delaysec2=str2num(data.step_cellarr.stepidx{1}{4});
    delay2_sec = delaymin2*60 + delaysec2;
    pause(delay2_sec + 1);   %pause to avoid DL timeout (delay + 1 sec)
  else              %use basic mode delay
    pause((data.delay_val*60) + 1);  
  end;
  out = fscanf(handles.s);         %read response
  while (isempty(findstr('>',out)))           %read buffer until '>' found
    if (isempty(out))   %input buffer is empty, break to avoid infinite
      break;               %  loop (ie, never found '>' terminator
    end
    out = fscanf(handles.s);
  end

  data = get(handles.figure1,'UserData');
  data.startbutpress_flg = 0;       %reset start button pressed flag
  set(handles.figure1,'UserData',data);
  
  %After start button processing complete then activate continuous update
  pump_gui2('UpdBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
elseif ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 0))
  data = get(handles.figure1,'UserData');
  data.startbutpress_flg = 0;       %clear press
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');
end;  %DL check "if"


% --- Executes on button press in StopBut.
function StopBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
  
  chkbutenb_str = get(handles.StopBut,'Enable');
  
  if (data.DLsemaphore_flg == 0)   
    pump_gui2('StopBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  elseif (strcmp(chkbutenb_str,'on') == 1)  
      %only allow button press queue if button active         
    data.stopbutpress_flg = 1;  
    data.oneORmorebutpress_flg = 1;
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
  end;
end;


function StopBut_ButtonDownFcn(hObject, eventdata, handles)
chkbutenb_str = get(handles.StopBut,'Enable');

[retstat] = chkNterm_link(handles.s,handles.figure1);
if ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 1))
  data = get(handles.figure1,'UserData');

  if (data.stoponce_flg == 0)     %only continue if first press of stop

    runupdflg = 0;                  %create and initialize run update flag

    if (data.ceaseupd_flg==1)   %if ceaseupd_flg previously set by "pause",
      runupdflg = 1;            %  then set this special case flag
    end;
    
    data.resetlock_flg = 0;                 %disable reset button lock
    data.ceaseupd_flg = 1;                   %disable status update flag
    if (data.oneupdate_flg ~= 2)
      data.oneupdate_flg = 1;                   %reset one-time update flag
    end;
    data.stoponce_flg = 1;                  %set stop once flag
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
  
    keybutthnds = [handles.PausBut,handles.StopBut];
    set(keybutthnds,'Enable','off');
    keybutthnds2 = [handles.StrtBut,handles.MultStepRadioBut,...
                   handles.SnglStepRadioBut];
    set(keybutthnds2,'Enable','on');
    
      %only if MS mode selected, re-activate send steps button
    if (get(handles.MultStepRadioBut,'Value') == 1)
      keybutthnds=[handles.SendStepsBut,handles.ApplyParamBut,...
                   handles.AddBefBut,handles.AddAftBut,handles.RemStepBut];
      set(keybutthnds,'Enable','on');
    end;
    
    out = fscanf(handles.s);
    while ~isempty(out)           %purge buffer before send new command    
      out = fscanf(handles.s);
    end
    
    fprintf(handles.s,'stop');
    pause(data.pausetm);                     
    out = fscanf(handles.s);      
    while (isempty(findstr('>',out)))
      if (isempty(out))   
        break;               
      end
      out = fscanf(handles.s);
    end
  
    data = get(handles.figure1,'UserData');

    if (runupdflg==1)  %special case, if previously stopped upd by "pause"
                       %  then need to run once more to register "stop"
                       %  status.
      pump_gui2('UpdBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    end;
  end;  %double press "if"
  
  data = get(handles.figure1,'UserData');
  data.stopbutpress_flg = 0;       %whether stop processing executed or
                                   %  user error, clear stop button press
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');
elseif ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 0))
  data = get(handles.figure1,'UserData');
  data.stopbutpress_flg = 0;
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');
end;   %DL chk "if"


% --- Executes on button press in PausBut.
function PausBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
    
  chkbutenb_str = get(handles.PausBut,'Enable');
  
  if (data.DLsemaphore_flg == 0)   
    pump_gui2('PausBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  elseif (strcmp(chkbutenb_str,'on') == 1)     
    data.pausebutpress_flg = 1;  
    data.oneORmorebutpress_flg = 1;
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
  end;
end;


function PausBut_ButtonDownFcn(hObject, eventdata, handles)
chkbutenb_str = get(handles.PausBut,'Enable');

[retstat] = chkNterm_link(handles.s,handles.figure1);
if ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 1))
  data = get(handles.figure1,'UserData');

  data.ceaseupd_flg = 1;         
  if data.oneupdate_flg ~= 2
    data.oneupdate_flg = 1;                   %reset one-time update flag
  end;
  data.resetlock_flg = 1;
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');

  set(handles.StrtBut,'Enable','on');  %re-activate start button
  set(handles.PausBut,'Enable','off');
  
  out = fscanf(handles.s);
  while ~isempty(out)           %purge buffer before send new command    
    out = fscanf(handles.s);
  end
  
  fprintf(handles.s,'pause');
  pause(data.pausetm);                     
  out = fscanf(handles.s);      
  while (isempty(findstr('>',out)))
    if (isempty(out))   
      break;               
    end
    out = fscanf(handles.s);
  end
  
  data = get(handles.figure1,'UserData');
  data.pausebutpress_flg = 0;
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');
elseif ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 0))
  data = get(handles.figure1,'UserData');
  data.pausebutpress_flg = 0;
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');
end;  %DL chk "if"


function PumpStatDisp_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function PumpStatDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function ElapTmDisp_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function ElapTmDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function DispensVolDisp_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function DispensVolDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in QuitBut.
function QuitBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
    
  if (data.DLsemaphore_flg == 0)   
    pump_gui2('QuitBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  else               
    data.quitbutpress_flg = 1;  
    data.oneORmorebutpress_flg = 1;
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
  end;
end;


function QuitBut_ButtonDownFcn(hObject, eventdata, handles)
%Quit the tool dialog
answer = questdlg({'Are you sure you want to quit?'},'Quit',...
            'Yes','No','No');
if ~isempty(answer)
  switch answer
    case 'Yes'
      if (ishandle(handles.figure1) == 1)
        data = get(handles.figure1,'UserData');
        data.killGUI_flg = 1;
        set(handles.figure1,'UserData',data);
        
        %only execute clean-up here if not called through service button 
        %  func, if so defer command
        if (data.oneORmorebutpress_flg == 0)
          delete(data.cleanupobj); %indirectly close serial port and clean-up
          closereq;
        else
          data.quitbutpress_flg = 0;
          set(handles.figure1,'UserData',data);
        end;
      end;
    case 'No'
      data = get(handles.figure1,'UserData');
      data.quitbutpress_flg = 0;
      set(handles.figure1,'UserData',data);
    otherwise
      data = get(handles.figure1,'UserData');
      data.quitbutpress_flg = 0;
      set(handles.figure1,'UserData',data);
    end
end

% --- Executes on button press in AboutBut.
function AboutBut_Callback(hObject, eventdata, handles)
uiwait(msgbox({'Chemyx Advanced Syringe Pump Controller','Version 0.2',...
        'Chemyx, Inc.','',...
        'Developed by HTCV Information, LLC, htcveng@gmail.com.','',...
        'Software licence agreement can be found in same directory as',...
        'the MATLAB script.'},'About','modal'));      
                            %wait for user to click OK before continue

function DLResBut_Callback(hObject, eventdata, handles)
data = get(handles.figure1,'UserData');
    
if ((data.stoponce_flg == 1) & (data.DLsemaphore_flg == 0))    
    %only allow reset if pump stopped and DL not busy
  fclose(handles.s)                              %close serial port
  com_strmx=get(handles.DLComPopup,'String');    %read selected com port
  strmx_idx=get(handles.DLComPopup,'Value');
  selcom_str=com_strmx(strmx_idx,:);
  
  baud_strmx = get(handles.BaudPopUp,'String');  %get selected baud rate
  baud_idx = get(handles.BaudPopUp,'Value');
  baud_str = baud_strmx(baud_idx,:);
  baud_dec = str2num(baud_str);
  
  %check if port available
  availports=getAvailableComPort();
  [validchk] = validport(selcom_str,availports);

  if (find(validchk)==1) 
    set(handles.s,'BaudRate',baud_dec);            %update serial settings
    set(handles.s,'Port',com_strmx(strmx_idx,:));     
  
    fopen(handles.s);               %re-open serial port with new settings
    
    pause(3.0);       %pause to give system time to reset
    
    out = fscanf(handles.s);
    while ~isempty(out)           %purge buffer before send new command    
      out = fscanf(handles.s);
    end;
    
    data = get(handles.figure1,'UserData');
  else
    display('ERROR: Selected COM port is not available.');
    delete(data.cleanupobj); %indirectly close serial port and clean-up
    closereq;
  end;
end;        %stopped "if"

function DLComPopup_Callback(hObject, eventdata, handles)


function DLComPopup_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function TmUnitDisp_Callback(hObject, eventdata, handles)


function TmUnitDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function UpdBut_ButtonDownFcn(hObject, eventdata, handles)
%##########################################################################
%START of continuous update
data = get(handles.figure1,'UserData');     %get shared data first time

while ((data.ceaseupd_flg == 0) | (data.oneupdate_flg == 2) | (data.oneupdate_flg == 1))
  %start/continue updating if no stop flag set OR
  %  requesting one last update
  
  data.DLsemaphore_flg = 1;                  %(re-)lock DL
  set(handles.figure1,'UserData',data);

  PumpStatDisp_flg=0;
  
  %check serial port status before send data
  %  if issue, clean-up serial port and shutdown GUI
  %  needed to prevent hard MATLAB crash due to DL disconnect
  [retstat] = chkNterm_link(handles.s,handles.figure1);
  if (retstat == 1)  %if shutdown initiated
    break;           %  then exit while loop
  end;
  
  data = get(handles.figure1,'UserData');
  
  fprintf(handles.s,'status');     
  pause(data.pausetm);                     
  out = fscanf(handles.s);
  while (isempty(findstr('>',out)))
    if (isempty(out))   
      break;               
    end
    
    out_num = str2num(out(1));
  
    if ((out_num==0) | (out_num==1) | (out_num==2) | (out_num==3) |...
        (out_num==4) | (out_num==5))      
                    %check for 0-5 for valid status
      if (out_num==0)
        set(handles.PumpStatDisp,'String','Stopped'); %update text field
      elseif (out_num==1)
        set(handles.PumpStatDisp,'String','Running');
      elseif (out_num==2)
        set(handles.PumpStatDisp,'String','Paused');
      elseif (out_num==3)
        set(handles.PumpStatDisp,'String','Stopped / Delayed');
      elseif (out_num==4)
        set(handles.PumpStatDisp,'String','Pump Stalled');
      elseif (out_num==5)
        set(handles.PumpStatDisp,'String','Pump Error');
      end
      PumpStatDisp_flg=1;                      %set flag to indicate update
    end  %valid number "if"

    out = fscanf(handles.s);                     %read next line
  end
  if (PumpStatDisp_flg==0)                %if never got a valid response
    set(handles.PumpStatDisp,'String','Missing');
  end

  %########################################################################
  %Check for button presses
  %START
  if (ishandle(handles.figure1) == 1)
    data = get(handles.figure1,'UserData');   
    data.DLsemaphore_flg = 0;                  
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
    if (data.oneORmorebutpress_flg == 1)
      pump_gui2('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    end;
    data = get(handles.figure1,'UserData');    
    if (data.killGUI_flg == 1)
      delete(data.cleanupobj);
      closereq;
      break;
    end;
  else
    break;
  end;
  %END
  %########################################################################
  
  [retstat] = chkNterm_link(handles.s,handles.figure1);
  if (retstat == 1)  
    break;
  end;
  
  data = get(handles.figure1,'UserData');
  
  ElapTmDisp_flg=0;
  fprintf(handles.s,'elapsed time');     
  pause(data.pausetm);                     
  out = fscanf(handles.s);
  while (isempty(findstr('>',out)))
    if (isempty(out))   
      break;               
    end
  
    eqidx = findstr('=',out);
    if (~isempty(eqidx))      %only if found '=' sign in field
                            %  isolate extent of data characters
      %first non-matching character (ie, not a digit or '.') after '= ' is 
      %  one past end of data (ie, remove one index for proper end)
      maxch=length(out);
      chidx=eqidx+1;    %skip past equal sign and first blank space
      endcharidx=0;     %initialize end character index
      while (endcharidx==0)
        chidx=chidx+1;        %increment character index
        if (chidx > maxch)    %of exceed out vector length
          break;              %break out of while loop
        else                  %test character
          if isempty(findstr(out(chidx),handles.digNperiod))  %found "last+1" char
            endcharidx=chidx-1;
          end;
        end
      end  %end char "while"
  
      if ((~isempty(eqidx)) & (endcharidx~=0))      
        %if equal sign character present for data line and found valid end char
      
        %convert raw time (fractions of minute) to HH:MM:SS format
        tottm_secs = str2num(out((eqidx+1):endcharidx))*60;
  
        hrs_num  = floor(tottm_secs/3600);
        min_num  = floor((tottm_secs-hrs_num*3600)/60);
        sec_num  = round(tottm_secs - hrs_num*3600 - min_num*60);
      
        if hrs_num < 10
          hrs_str = ['0' num2str(hrs_num)];
        else
          hrs_str = num2str(hrs_num);
        end;

        if min_num < 10
          min_str = ['0' num2str(min_num)];
        else
          min_str = num2str(min_num);
        end;

        if sec_num < 10
          sec_str = ['0' num2str(sec_num)];
        else
          sec_str = num2str(sec_num);
        end;
      
        time_str = [hrs_str,':',min_str,':',sec_str];
      
        set(handles.ElapTmDisp,'String',time_str);
      
        ElapTmDisp_flg=1;
      end
    end  %non-empty eqidx "if"
  
    out = fscanf(handles.s);
  end
  if (ElapTmDisp_flg==0)
    set(handles.ElapTmDisp,'String','Missing');
  end

  %########################################################################
  %Check for button presses
  %START
  if (ishandle(handles.figure1) == 1)
    data = get(handles.figure1,'UserData');   
    data.DLsemaphore_flg = 0;                  
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
    if (data.oneORmorebutpress_flg == 1)
      pump_gui2('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    end;
    data = get(handles.figure1,'UserData');       
    if (data.killGUI_flg == 1)
      delete(data.cleanupobj);
      closereq;
      break;
    end;
  else
    break;
  end;
  %END
  %########################################################################
  
  [retstat] = chkNterm_link(handles.s,handles.figure1);
  if (retstat == 1)  
    break;
  end;
  
  data = get(handles.figure1,'UserData');
  
  DispensVolDisp_flg=0;
  fprintf(handles.s,'dispensed volume');     
  pause(data.pausetm);                     
  out = fscanf(handles.s);

  while (isempty(findstr('>',out)))
    if (isempty(out))   
      break;               
    end
  
    eqidx = findstr('=',out);
    if (~isempty(eqidx))      %only if found '=' sign in field
                            %  isolate extent of data characters
      %first non-matching character (ie, not a digit or '.') after '= ' is 
      %  one past end of data (ie, remove one index for proper end)
      maxch=length(out);
      chidx=eqidx+1;    %skip past equal sign and first blank space
      endcharidx=0;     %initialize end character index
      while (endcharidx==0)
        chidx=chidx+1;        %increment character index
        if (chidx > maxch)    %of exceed out vector length
          break;              %break out of while loop
        else                  %test character
          if isempty(findstr(out(chidx),handles.digNperiod))  %found "last+1" char
            endcharidx=chidx-1;
          end;
        end
      end  %end char "while"
  
      if ((~isempty(eqidx)) & (endcharidx~=0))      
        %if equal sign character present for data line and found valid end char
        set(handles.DispensVolDisp,'String',out((eqidx+1):endcharidx));
        DispensVolDisp_flg=1;
      end
    end  %non-empty eqidx "if"
  
    out = fscanf(handles.s);
  end
  if (DispensVolDisp_flg==0)
    set(handles.DispensVolDisp,'String','Missing');
  end

  data = get(handles.figure1,'UserData');
  
  %########################################################################
  %Check for button presses
  %START
  if (ishandle(handles.figure1) == 1)
    data = get(handles.figure1,'UserData');   
    data.DLsemaphore_flg = 0;                  
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
    if (data.oneORmorebutpress_flg == 1)
      pump_gui2('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    end;
    data = get(handles.figure1,'UserData');      
    if (data.killGUI_flg == 1)
      delete(data.cleanupobj);
      closereq;
      break;
    end;
  else
    break;
  end;
  %END
  %########################################################################
  
  data = get(handles.figure1,'UserData');
  if (data.onetimeunitupd_flg == 1) 
    [retstat] = chkNterm_link(handles.s,handles.figure1);
    if (retstat == 1)  
      break;
    end;
    
    data = get(handles.figure1,'UserData');
    
    fprintf(handles.s,'view parameter');  %determine rate units
    pause(data.pausetm);                     
    out = fscanf(handles.s);      
    while (isempty(findstr('>',out)))
      if (isempty(out))   
        break;               
      end
      
      unitline = findstr('unit',out);       %check for data line
      if (~isempty(unitline))               %if so, continue
    
        eqidx = findstr('=',out);
    
        if (~isempty(eqidx))
          out_num = str2num(out(eqidx+2));
        end
    
        if ((out_num==0) | (out_num==1))
          set(handles.VolUnitDisp,'String','ml'); %update text field
        elseif ((out_num==2) | (out_num==3))
          set(handles.VolUnitDisp,'String','ul');
        else
          set(handles.VolUnitDisp,'String','Unk');
        end
      end
      
      data = get(handles.figure1,'UserData');
      delayline = findstr('delay',out);       %check for data line
      if (~isempty(delayline))                %if so, continue
        eqidx = findstr('=',out);
        if (~isempty(eqidx))
          maxch=length(out);
          chidx=eqidx+1;    %skip past equal sign and first blank space
          endcharidx=0;     %initialize end character index
          while (endcharidx==0)
            chidx=chidx+1;        %increment character index
            if (chidx > maxch)    %if exceed out vector length
              break;              %break out of while loop
            else                  %test character
              if isempty(findstr(out(chidx),handles.digNperiod))  %found "last+1" char
                endcharidx=chidx-1;
              end;
            end
          end  %end char "while"
          if ((~isempty(eqidx)) & (endcharidx~=0))   %if found valid value
            data.delay_val = str2num(out((eqidx+2):endcharidx));
            set(handles.figure1,'UserData',data);    %capture
            data = get(handles.figure1,'UserData');
          end;
        end  %equal sign check "if"
      end  %delay line "if"
  
      out = fscanf(handles.s);
    end  
    
    data.onetimeunitupd_flg = 0;              %clear flag
    set(handles.figure1,'UserData',data);
  end %end onetimeunitupd_flg "if"
  
  data = get(handles.figure1,'UserData');

  %########################################################################
  %Check for button presses
  %START
  %only continue updating if GUI still active,
  %  but temporarily pause if there has been a button press
  if (ishandle(handles.figure1) == 1)
    data = get(handles.figure1,'UserData');   %update shared data
    
    data.DLsemaphore_flg = 0;                  %unlock DL
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
    
    %check if any buttons pressed during last update
    if (data.oneORmorebutpress_flg == 1)   %if so, then service button press(es)
      pump_gui2('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    end;
    
    data = get(handles.figure1,'UserData');       %upd shared data (ongoing)
    
    %check for GUI shutdown case from Quit button
    if (data.killGUI_flg == 1)
      delete(data.cleanupobj); %indirectly close serial port and clean-up
      closereq;
      break;
    end;
  else
    break;                          %otherwise exit while loop
  end;
  
  data = get(handles.figure1,'UserData');
  if (data.oneupdate_flg == 1)              %if one time upd set,
    data.oneupdate_flg = 2;                 %  perpetuate once more through
    set(handles.figure1,'UserData',data);
  elseif (data.oneupdate_flg == 2)
    data.oneupdate_flg = 0;                 %reset one time flag
    set(handles.figure1,'UserData',data);
  end;
  data = get(handles.figure1,'UserData');
  %END
  %########################################################################
  
end   %outer stop "while" loop
%END of continuous update
%##########################################################################

%Only gets called by UpdBut_ButtonDownFcn
function Service_ButPress_ButtonDownFcn(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');   %update shared data
  
  while (data.oneORmorebutpress_flg == 1)  %loop while at least one button
                                           %  press request present
                                           
    %at least one button has been pressed so check each one
    if (data.startbutpress_flg == 1)    %execute start button processing
      %should not have occurred, user error (must have pressed start button
      %  extra time unnecessarily)
      data.startbutpress_flg = 0;   %reset so that can exit service button
                                    %  loop
      set(handles.figure1,'UserData',data); 
 
    elseif (data.stopbutpress_flg == 1)
      pump_gui2('StopBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    elseif (data.pausebutpress_flg == 1)
      pump_gui2('PausBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    elseif (data.quitbutpress_flg == 1)
      pump_gui2('QuitBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
   
    else
      break;          %if get here, something wrong so break out of while
    end;
  
    data = get(handles.figure1,'UserData');   %update shared data
    
    %if any button press request still outstanding then update overall flag
    if ((data.startbutpress_flg == 1) | (data.stopbutpress_flg == 1) | ...
         (data.pausebutpress_flg == 1) | (data.quitbutpress_flg == 1))
      data.oneORmorebutpress_flg = 1;
    else
      data.oneORmorebutpress_flg = 0;  %otherwise, clear flag
    end;
    set(handles.figure1,'UserData',data);  
    
    data = get(handles.figure1,'UserData');
    
  end;  %end while
  
end;


% --- Executes on selection change in RateUnitPopUp.
function RateUnitPopUp_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  rateunitsel = get(handles.RateUnitPopUp,'Value');
  if ((rateunitsel == 1.0) | (rateunitsel == 2.0))
    set(handles.VolUnitDisp,'String','ml');
  elseif ((rateunitsel == 3.0) | (rateunitsel == 4.0))
    set(handles.VolUnitDisp,'String','ul');
  else
    display('ERROR: Invalid rate units.');
  end;
  rateunitlist_strvec = get(handles.RateUnitPopUp,'String');
  set(handles.RateUnitDisp,'String',rateunitlist_strvec((rateunitsel),:));
end;

% --- Executes during object creation, after setting all properties.
function RateUnitPopUp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function DiamDisp_Callback(hObject, eventdata, handles)
        
% --- Executes during object creation, after setting all properties.
function DiamDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function NumStepDisp_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  data = get(handles.figure1,'UserData');

  nsteps = str2num(get(handles.NumStepDisp,'String'));
  
  max_nsteps=99;
  if nsteps > max_nsteps
    nsteps = max_nsteps;            %override nsteps
    set(handles.NumStepDisp,'String',num2str(max_nsteps));
  end;

  %re-create and re-initialize new cell array and save to shared memory
  %elem#    description
  %  1      volume
  %  2      rate
  %  3      delay min
  %  4      delay sec
  data.step_cellarr = stepdata(nsteps);
  for cj=1:nsteps
    data.step_cellarr.stepidx{cj} = cell(1,4);
    data.step_cellarr.stepidx{cj}{1}='0.0';
    data.step_cellarr.stepidx{cj}{2}='0.0';
    data.step_cellarr.stepidx{cj}{3}='0';
    data.step_cellarr.stepidx{cj}{4}='0';
  end;
  set(handles.figure1,'UserData',data); 
  data = get(handles.figure1,'UserData');

  %create and update current step list and selection index
  csidx_str=cell(nsteps,1);
  for ck=1:nsteps
    currstr = num2str(ck);
    if length(currstr)==1
      csidx_str{ck}=['0',currstr];
    else
      csidx_str{ck}=currstr;
    end;
  end;
  
  set(handles.CurrStepPopUp,'String',csidx_str);
  set(handles.CurrStepPopUp,'Value',1.0);
  
  %update display for default index 1 step parameters from cell array
  set(handles.VolDisp,'String',data.step_cellarr.stepidx{1}{1});
  set(handles.RateDisp,'String',data.step_cellarr.stepidx{1}{2});
  set(handles.DelayMinDisp,'String',data.step_cellarr.stepidx{1}{3});
  set(handles.DelaySecDisp,'String',data.step_cellarr.stepidx{1}{4});
end;

function NumStepDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function RateUnitDisp_Callback(hObject, eventdata, handles)


function RateUnitDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function VolUnitDisp_Callback(hObject, eventdata, handles)


function VolUnitDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function DelaySecDisp_Callback(hObject, eventdata, handles)


function DelaySecDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function DelayMinDisp_Callback(hObject, eventdata, handles)


function DelayMinDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function VolDisp_Callback(hObject, eventdata, handles)


function VolDisp_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function RateDisp_Callback(hObject, eventdata, handles)


function RateDisp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function CurrStepPopUp_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  data = get(handles.figure1,'UserData');
  
  cidx = get(handles.CurrStepPopUp,'Value');
  
  %update step parameter display for current step data from cell array
  ctmp = data.step_cellarr.stepidx{cidx}{1};
  if ctmp(1) == '-'
    volstr = ctmp(2:end);       %remove negative sign for volume value
    set(handles.WithRadioBut,'Value',1.0);   %set withdraw flow direction
  else
    volstr = ctmp;
    set(handles.InfusRadioBut,'Value',1.0);  %set infuse flow direction
  end;
  
  set(handles.VolDisp,'String',volstr);
  set(handles.RateDisp,'String',data.step_cellarr.stepidx{cidx}{2});
  set(handles.DelayMinDisp,'String',data.step_cellarr.stepidx{cidx}{3});
  set(handles.DelaySecDisp,'String',data.step_cellarr.stepidx{cidx}{4});
end;

function CurrStepPopUp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function ApplyParamBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  data = get(handles.figure1,'UserData');
  
  chkbutenb_str = get(handles.SendStepsBut,'Enable');

  if (strcmp(chkbutenb_str,'on') == 1)   %check if button enabled
    csidx = get(handles.CurrStepPopUp,'Value');  %grab current step idx
   
    %save display results into step cell array
    if (get(handles.WithRadioBut,'Value') == 1)
      vol_str = ['-',get(handles.VolDisp,'String')];  %add neg sign
    else                                              %  if withdraw
      vol_str = get(handles.VolDisp,'String');
    end;
    
    data.step_cellarr.stepidx{csidx}{1}=vol_str;
    data.step_cellarr.stepidx{csidx}{2}=get(handles.RateDisp,'String');
    data.step_cellarr.stepidx{csidx}{3}=get(handles.DelayMinDisp,'String');
    data.step_cellarr.stepidx{csidx}{4}=get(handles.DelaySecDisp,'String');

    set(handles.figure1,'UserData',data);       %save results
    data = get(handles.figure1,'UserData');
  end;
end;

function SendStepsBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  data = get(handles.figure1,'UserData');
  stepfail_flg = 0;                      %reset step fail flag  
  
  if ((data.stoponce_flg == 1) & (data.DLsemaphore_flg == 0) & ...
      (stepfail_flg ==0))    
    %only allow button to work if pump stopped, DL not busy, and if
    %  in multi-step mode
  
    chkbutenb_str = get(handles.SendStepsBut,'Enable');

    [retstat] = chkNterm_link(handles.s,handles.figure1);
    if ((retstat == 0) & (strcmp(chkbutenb_str,'on') == 1)) 
        %if no DL OR button disabled conditions
      
      nsteps = str2num(get(handles.NumStepDisp,'String'));
      
      %####################################################################
      %check for
      %1.zero values for diameter, volumes, and rates
      %2.digit content of 0-9 and '.' for all parameters. inherent
      %  check if negative, except add '-' for volume.
      %3.not more than one '.' digit for all parameters.
     
      diaperiod_cntr = 0;       %intialize '.' counter
      
      %diameter checks
      dia_str = get(handles.DiamDisp,'String');         
      dia_dec = str2num(dia_str);
      if (dia_dec == 0)
        display('ERROR: Invalid syringe diameter.');
        stepfail_flg = 1;       %set fail flage
      end;
      [junk nchar] = size(dia_str);
      for di=1:nchar
        if isempty(findstr(dia_str(di),handles.digNperiod))
          txt_str = ['ERROR: Invalid syringe diameter.'];
          disp(txt_str);
          stepfail_flg = 1;
        end;
        if strcmp(dia_str(di),'.')
          diaperiod_cntr = diaperiod_cntr + 1;
        end;
      end;
      if diaperiod_cntr > 1
        txt_str = ['ERROR: Invalid syringe diameter.'];
        disp(txt_str);
        stepfail_flg = 1;
      end;
      
      %####################################################################
      %if no issues with diameter then send pump rate units and diameter 
      %  and read back vol/rate min/max limits required for additional and
      %  subsequent vol/rate checks
      
      %Set rate units - must do this before set diameter
      data = get(handles.figure1,'UserData');
      [retstat] = chkNterm_link(handles.s,handles.figure1);
      if ((retstat == 0) & (stepfail_flg == 0))        
          %if no DL issues or step param issues (so far)
        unitidx = get(handles.RateUnitPopUp,'Value') - 1;
          %get selected units and adjust to 0-based
        unitcmd_str = ['set units ',num2str(unitidx)];
        fprintf(handles.s,unitcmd_str);
        pause(data.pausetm);                     
        out = fscanf(handles.s);      
        while (isempty(findstr('>',out)))
          if (isempty(out))   
            break;               
          end;
          out = fscanf(handles.s);
        end;  
      end;
      
      %Set syringe diameter
      data = get(handles.figure1,'UserData');
      [retstat] = chkNterm_link(handles.s,handles.figure1);
      if ((retstat == 0) & (stepfail_flg == 0))        
                           %if no DL issues or step param issues (so far)
        diamval_str = get(handles.DiamDisp,'String');
        diamcmd_str = ['set diameter ',diamval_str];
        fprintf(handles.s,diamcmd_str);
        pause(data.pausetm);                     
        out = fscanf(handles.s);      
        while (isempty(findstr('>',out)))
          if (isempty(out))   
            break;               
          end;
          out = fscanf(handles.s);
        end;
      end;
      
      %get volume and rate min/max limits
      data = get(handles.figure1,'UserData');
      [retstat] = chkNterm_link(handles.s,handles.figure1);
      if ((retstat == 0) & (stepfail_flg == 0))        
                           %if no DL issues or step param issues (so far)
        fprintf(handles.s,'read limit parameter');
        pause(data.pausetm);                     
        out = fscanf(handles.s);      
        while (isempty(findstr('>',out)))
          if (isempty(out))   
            break;               
          end;
          
          %read buffer until get line with 4 periods
          numperiods = length(findstr('.',out));
          if (numperiods == 4)  %this is the line with limit values
            dataidx = findstr(' ',out);  %find space delimiters to isolate
                                         %  all but last value
            
            %find first non-matching character 
            %  (ie, not a digit OR '.' OR ' ')
            maxch=length(out);
            chidx=1; 
            endcharidx=0;
            while (endcharidx==0)
              chidx=chidx+1; 
              if (chidx > maxch)
                break;              
              else          
                if isempty(findstr(out(chidx),handles.digNperiodNspace))
                  endcharidx=chidx-1;
                end;
              end
            end
            
            %only convert and set max/min limits if able to fully
            %  parse data
            if (endcharidx ~= 0)
              data.ratemax = str2num(out(1:(dataidx(1)-1)));
              data.ratemin = str2num(out((dataidx(1)+1):(dataidx(2)-1)));
              data.volmax = str2num(out((dataidx(2)+1):(dataidx(3)-1)));
              data.volmin = str2num(out((dataidx(3)+1):endcharidx));
              
              set(handles.figure1,'UserData',data);
              data = get(handles.figure1,'UserData');
            else
              txt_str = ['ERROR: Unable to read volume/rate parameter limits.'];
              disp(txt_str);
              stepfail_flg = 1;       %otherwise set fail flag
            end;
          end;
          out = fscanf(handles.s);
        end;
      end;
      %####################################################################
        
      data = get(handles.figure1,'UserData');
      for si=1:nsteps
        volperiod_cntr = 0;     %reset '.' counters for each step
        ratperiod_cntr = 0;
        delmin_percntr = 0;
        delsec_percntr = 0;
          
        %volume checks
        vol_str = data.step_cellarr.stepidx{si}{1};  %chk if zero
        vol_dec = str2num(vol_str);
        if (vol_dec == 0)
          txt_str = ['ERROR: Step=',num2str(si),' invalid syringe volume.'];
          disp(txt_str);
          stepfail_flg = 1;       %set fail flag
        end;
        [junk nchar] = size(vol_str);   %check 0-9 OR '.' OR '-' for digits
        for vi=1:nchar
          if isempty(findstr(vol_str(vi),handles.digNperiodNneg))
            txt_str = ['ERROR: Step=',num2str(si),' invalid syringe volume.'];
            disp(txt_str);
            stepfail_flg = 1;
            break;              %already issue, don't have to look further
          end;
          if strcmp(vol_str(vi),'.')
            volperiod_cntr = volperiod_cntr + 1;    %increment . counter
          end;
        end;
        if (stepfail_flg == 0)  %if no previous errors. including
                                %  extracting vol/rate limit parmaters,
                                %  the check volume against limits
          if ((abs(vol_dec) > data.volmax) | (abs(vol_dec) < data.volmin))
              %if volume exceeds limits then flag and capture error
            txt_str = ['ERROR: Step=',num2str(si),...
                       ' syringe volume outside of allowable limits.'];  
            disp(txt_str);
            stepfail_flg = 1;   
          end;  
        end;
        
        %rate checks
        rate_str = data.step_cellarr.stepidx{si}{2};
        rate_dec = str2num(rate_str);
        if (rate_dec == 0)
          txt_str = ['ERROR: Step=',num2str(si),' invalid syringe rate.'];
          disp(txt_str);
          stepfail_flg = 1;
        end;
        [junk nchar] = size(rate_str);
        for ri=1:nchar
          if isempty(findstr(rate_str(ri),handles.digNperiod))
            txt_str = ['ERROR: Step=',num2str(si),' invalid syringe rate.'];
            disp(txt_str);
            stepfail_flg = 1;
            break;
          end;
          if strcmp(rate_str(ri),'.')
            ratperiod_cntr = ratperiod_cntr + 1;
          end;
        end;
        if (stepfail_flg == 0)
          if ((rate_dec > data.ratemax) | (rate_dec < data.ratemin))
              %if volume exceeds limits then flag and capture error
            txt_str = ['ERROR: Step=',num2str(si),...
                       ' syringe rate outside of allowable limits.'];  
            disp(txt_str);
            stepfail_flg = 1;   
          end;  
        end;
        
        %delay min checks
        delmin_str = data.step_cellarr.stepidx{si}{3};
        [junk nchar] = size(delmin_str);
        for dmi=1:nchar
          if isempty(findstr(delmin_str(dmi),handles.digNperiod))
            txt_str = ['ERROR: Step=',num2str(si),' invalid delay min.'];
            disp(txt_str);
            stepfail_flg = 1;
            break;
          end;
          if strcmp(delmin_str(dmi),'.')
            delmin_percntr = delmin_percntr + 1;
          end;
        end;
        
        %delay sec checks
        delsec_str = data.step_cellarr.stepidx{si}{4};
        [junk nchar] = size(delsec_str);
        for dsi=1:nchar
          if isempty(findstr(delsec_str(dsi),handles.digNperiod))
            txt_str = ['ERROR: Step=',num2str(si),' invalid delay sec.'];
            disp(txt_str);
            stepfail_flg = 1;
            break;
          end;
          if strcmp(delsec_str(dsi),'.')
            delsec_percntr = delsec_percntr + 1;
          end;
        end;
        
        %assess '.' counters
        if volperiod_cntr > 1
          txt_str = ['ERROR: Step=',num2str(si),' invalid syringe volume.'];
          disp(txt_str);
          stepfail_flg = 1;
        end;
        if ratperiod_cntr > 1
          txt_str = ['ERROR: Step=',num2str(si),' invalid syringe rate.'];
          disp(txt_str);
          stepfail_flg = 1;
        end;
        if delmin_percntr > 1
          txt_str = ['ERROR: Step=',num2str(si),' invalid delay min.'];
          disp(txt_str);
          stepfail_flg = 1;
        end;
        if delsec_percntr > 1
          txt_str = ['ERROR: Step=',num2str(si),' invalid delay sec.'];
          disp(txt_str);
          stepfail_flg = 1;
        end;
      end;  %end nsteps "for" loop
      
      if (stepfail_flg == 1)   %if error occurs at this stage
        uiwait(msgbox({'ERROR: Improper syringe diameter or',...
        'step data entered. See console for more details.',...
        ''},'ERROR','modal'));
      end;
      
      %end of parameter checks
      %####################################################################

      %####################################################################
      %Form and send pump set commands, if DL active
      data = get(handles.figure1,'UserData');
      
      %construct volume,rate,and delay value vectors from step cell array
      volval_str = [];      %initialize value character strings
      ratval_str = [];
      delval_str = [];
      
      for sc=1:nsteps
        delaymin_dec = str2num(data.step_cellarr.stepidx{sc}{3});
        delaysec_dec = str2num(data.step_cellarr.stepidx{sc}{4});
        delay_dec = delaymin_dec + delaysec_dec*(1/60);
        
        volval_str = [volval_str,data.step_cellarr.stepidx{sc}{1}];
        ratval_str = [ratval_str,data.step_cellarr.stepidx{sc}{2}];
        delval_str = [delval_str,num2str(delay_dec)];
        
        if (sc ~= nsteps)
          volval_str = [volval_str,','];       %add comma delimiter
          ratval_str = [ratval_str,','];       %  except last entry or
          delval_str = [delval_str,','];       %  single step cases
        end;
      end;
      
      %Set multi-step volume and check response to confirm that user is in 
      %  multi-step mode
      [retstat] = chkNterm_link(handles.s,handles.figure1);
      if ((retstat == 0) & (stepfail_flg == 0))   
        %if no DL issues or step param issues (so far)
        
        volcmd_str = ['set volume ',volval_str];
        fprintf(handles.s,volcmd_str);
        pause(data.pausetm);                     
        out = fscanf(handles.s);    
        
        mschk_flg = 0;     %initialize multi-step mode confirmation flag

        while (isempty(findstr('>',out)))
          if (isempty(out))   
            break;               
          end;
          
          if findstr('volume =',out) %if DL receive line is 'set volume'
                                    %  pump response, then assess if proper
                                    %  number of elements
            numcommas = length(findstr(',',out));
            if (numcommas + 1) == nsteps
              mschk_flg = 1;        %set multi-step mode confirmation flag
            end;
         end;
          out = fscanf(handles.s);
        end;
       
        if mschk_flg==0
          stepfail_flg = 1;       %set fail flag
          
          %display message dialog to warn user
          uiwait(msgbox({'ERROR: Pump is not in multi-step mode. User',...
        'must manually select multi-step mode directly',...
        'through the syringe pump menu interface.',''},'ERROR','modal'));      
        
        end;
      end;
      
      %Set multi-step rate
      [retstat] = chkNterm_link(handles.s,handles.figure1);
      if ((retstat == 0) & (stepfail_flg == 0))   
        %if no DL issues or step param issues (so far)
        
        ratcmd_str = ['set rate ',ratval_str];
        fprintf(handles.s,ratcmd_str);
        pause(data.pausetm);                     
        out = fscanf(handles.s);    

        while (isempty(findstr('>',out)))
          if (isempty(out))   
            break;               
          end;
          out = fscanf(handles.s);
        end;
      end;
      
      %Set multi-step delay
      [retstat] = chkNterm_link(handles.s,handles.figure1);
      if ((retstat == 0) & (stepfail_flg == 0))   
        %if no DL issues or step param issues (so far)
        
        delcmd_str = ['set delay ',delval_str];
        fprintf(handles.s,delcmd_str);
        pause(data.pausetm);                     
        out = fscanf(handles.s);    

        while (isempty(findstr('>',out)))
          if (isempty(out))   
            break;               
          end;
          out = fscanf(handles.s);
        end;
      end;

      %end form and send set commands
      %####################################################################
      
      %after successful 'send step' processing
      if (stepfail_flg == 0)   %if no errors then can continue
        uiwait(msgbox({'INFORMATION: Step data successfully sent to pump.',...
                       ''},'INFORMATION','modal'));
          
        keybutthnds = [handles.PausBut,handles.StopBut];
        set(keybutthnds,'Enable','off');
        keybutthnds2 = [handles.StrtBut];
        set(keybutthnds2,'Enable','on');
      else          %if something wrong, disable start button
        set(handles.StrtBut,'Enable','off');
      end;   %no step param error "if"
      
    end;    %no DL or button disabled issues "if"
  end;    %stopped and DL free "if"
end;   %GUI exists "if"

function PumpModePanel_SelectionChangeFcn(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  data = get(handles.figure1,'UserData');
    
  if ((data.stoponce_flg == 1) & (data.DLsemaphore_flg == 0))    
    %only allow button group processing if pump stopped and DL not busy

    switch get(eventdata.NewValue,'Tag')
      case 'SnglStepRadioBut'
         %if basic selected, disable 'send steps' button and
         %  enable pump control buttons
        keybutthnds=[handles.SendStepsBut,handles.ApplyParamBut,...
                   handles.AddBefBut,handles.AddAftBut,handles.RemStepBut];
        set(keybutthnds,'Enable','off');
        set(handles.StrtBut,'Enable','on');
        
      case 'MultStepRadioBut'
         %if multi-step, (re-)enable 'send steps' button and temporarily 
         %  disable pump control buttons
        keybutthnds=[handles.SendStepsBut,handles.ApplyParamBut,...
                  handles.AddBefBut,handles.AddAftBut,handles.RemStepBut];
        set(keybutthnds,'Enable','on');
        keybutthnds = [handles.StrtBut,handles.PausBut,handles.StopBut];
        set(keybutthnds,'Enable','off');
    end;
  end;
end;


function BaudPopUp_Callback(hObject, eventdata, handles)


function BaudPopUp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function RemStepBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)         %if GUI exists
  data = get(handles.figure1,'UserData');
  
  chkbutenb_str = get(handles.RemStepBut,'Enable');

  if (strcmp(chkbutenb_str,'on') == 1)   %check if button enabled
    remidx = get(handles.CurrStepPopUp,'Value');  %grab idx for remove step
    curr_nsteps = str2num(get(handles.NumStepDisp,'String'));
                        %separately grab existing total number of steps
                        
    new_nsteps = curr_nsteps - 1;       %remove one step
    if (new_nsteps > 0)     %check that at least one step to continue
      set(handles.NumStepDisp,'String',num2str(new_nsteps));
      
      curr_stepdata = data.step_cellarr;    %capture existing data
      
      new_arridx = 0;             %initialize new array index
      data.step_cellarr = stepdata(new_nsteps);  %create new array
      for newi=1:curr_nsteps    %copy all but removed step
        if (newi ~= remidx)
          new_arridx = new_arridx + 1;   %increment new array counter
          data.step_cellarr.stepidx{new_arridx} = ...
            curr_stepdata.stepidx{newi};
        end;
      end;
      
      set(handles.figure1,'UserData',data);       %save results
      data = get(handles.figure1,'UserData');
      
      %update current step list and selection index
      csidx_str=cell(new_nsteps,1);
      for ck2=1:new_nsteps
        currstr = num2str(ck2);
        if length(currstr)==1
          csidx_str{ck2}=['0',currstr];
        else
          csidx_str{ck2}=currstr;
        end;
      end;
      set(handles.CurrStepPopUp,'String',csidx_str);
      
      cidx=1;
      set(handles.CurrStepPopUp,'Value',cidx);    
                                            %upd display to 1st step params
      ctmp = data.step_cellarr.stepidx{cidx}{1};
      if ctmp(1) == '-'
        volstr = ctmp(2:end);       %remove negative sign for volume value
        set(handles.WithRadioBut,'Value',1.0); %set withdraw flow direction
      else
        volstr = ctmp;
        set(handles.InfusRadioBut,'Value',1.0);  %set infuse flow direction
      end;
      set(handles.VolDisp,'String',volstr);
      set(handles.RateDisp,'String',data.step_cellarr.stepidx{cidx}{2});
      set(handles.DelayMinDisp,'String',data.step_cellarr.stepidx{cidx}{3});
      set(handles.DelaySecDisp,'String',data.step_cellarr.stepidx{cidx}{4});
    else
      display('ERROR: Must have at least one step.');
    end;
    
  end;  %end button enabled "if"
end;   %end GUI exists "if"

function AddBefBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
  
  chkbutenb_str = get(handles.AddBefBut,'Enable');

  if (strcmp(chkbutenb_str,'on') == 1)   
    addidx = get(handles.CurrStepPopUp,'Value');  
    curr_nsteps = str2num(get(handles.NumStepDisp,'String'));
                        
    new_nsteps = curr_nsteps + 1;       
    if (new_nsteps < 100)     
      set(handles.NumStepDisp,'String',num2str(new_nsteps));
      
      curr_stepdata = data.step_cellarr;
      
      new_arridx = 0;             
      data.step_cellarr = stepdata(new_nsteps);  
      for newi=1:curr_nsteps    
        if (newi ~= addidx)
          new_arridx = new_arridx + 1;   
          data.step_cellarr.stepidx{new_arridx} = ...
            curr_stepdata.stepidx{newi};
        else  %do two updates, first new entry from currently displayed 
              %  step params
          new_arridx = new_arridx + 1;   
          newnetry_idx = new_arridx;
          
          %save display results into new inserted step cell array entry
          if (get(handles.WithRadioBut,'Value') == 1)
            volstr = ['-',get(handles.VolDisp,'String')];
          else                                            
            volstr = get(handles.VolDisp,'String');
          end;
          data.step_cellarr.stepidx{new_arridx}{1}=volstr;
          data.step_cellarr.stepidx{new_arridx}{2}=get(handles.RateDisp,'String');
          data.step_cellarr.stepidx{new_arridx}{3}=get(handles.DelayMinDisp,'String');
          data.step_cellarr.stepidx{new_arridx}{4}=get(handles.DelaySecDisp,'String');
        
          new_arridx = new_arridx + 1;     %then second from existing entry
          data.step_cellarr.stepidx{new_arridx} = ...
            curr_stepdata.stepidx{newi};
        end;
      end;
      
      set(handles.figure1,'UserData',data);       
      data = get(handles.figure1,'UserData');
      
      csidx_str=cell(new_nsteps,1);
      for ck2=1:new_nsteps
        currstr = num2str(ck2);
        if length(currstr)==1
          csidx_str{ck2}=['0',currstr];
        else
          csidx_str{ck2}=currstr;
        end;
      end;
      set(handles.CurrStepPopUp,'String',csidx_str);
      
      cidx=newnetry_idx;        %default on new entry step
      set(handles.CurrStepPopUp,'Value',cidx);
      ctmp = data.step_cellarr.stepidx{cidx}{1};
      if ctmp(1) == '-'
        volstr = ctmp(2:end);       %remove negative sign for volume value
        set(handles.WithRadioBut,'Value',1.0);   %set withdraw flow direction
      else
        volstr = ctmp;
        set(handles.InfusRadioBut,'Value',1.0);  %set infuse flow direction
      end;
      set(handles.VolDisp,'String',volstr);
      set(handles.RateDisp,'String',data.step_cellarr.stepidx{cidx}{2});
      set(handles.DelayMinDisp,'String',data.step_cellarr.stepidx{cidx}{3});
      set(handles.DelaySecDisp,'String',data.step_cellarr.stepidx{cidx}{4});
    else
      display('ERROR: Exceeded 99 step limit.');
    end;
    
  end;  %end button enabled "if"
end;   %end GUI exists "if"

function AddAftBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
  
  chkbutenb_str = get(handles.AddAftBut,'Enable');

  if (strcmp(chkbutenb_str,'on') == 1)   
    addidx = get(handles.CurrStepPopUp,'Value');  
    curr_nsteps = str2num(get(handles.NumStepDisp,'String'));
                        
    new_nsteps = curr_nsteps + 1;       
    if (new_nsteps < 100)     
      set(handles.NumStepDisp,'String',num2str(new_nsteps));
      
      curr_stepdata = data.step_cellarr;
      
      new_arridx = 0;             
      data.step_cellarr = stepdata(new_nsteps);  
      for newi=1:curr_nsteps    
        if (newi ~= addidx)
          new_arridx = new_arridx + 1;   
          data.step_cellarr.stepidx{new_arridx} = ...
            curr_stepdata.stepidx{newi};
        else                    %do two updates
          new_arridx = new_arridx + 1;     %first from existing entry
          data.step_cellarr.stepidx{new_arridx} = ...
            curr_stepdata.stepidx{newi};
              
          new_arridx = new_arridx + 1;   %then second, new entry from 
                                %currently displayed step params
          newnetry_idx = new_arridx;
          
          %save display results into new inserted step cell array entry
          if (get(handles.WithRadioBut,'Value') == 1)
            volstr = ['-',get(handles.VolDisp,'String')];
          else                                            
            volstr = get(handles.VolDisp,'String');
          end;
          data.step_cellarr.stepidx{new_arridx}{1}=volstr;
          data.step_cellarr.stepidx{new_arridx}{2}=get(handles.RateDisp,'String');
          data.step_cellarr.stepidx{new_arridx}{3}=get(handles.DelayMinDisp,'String');
          data.step_cellarr.stepidx{new_arridx}{4}=get(handles.DelaySecDisp,'String');
        end;
      end;
      
      set(handles.figure1,'UserData',data);       
      data = get(handles.figure1,'UserData');
      
      csidx_str=cell(new_nsteps,1);
      for ck2=1:new_nsteps
        currstr = num2str(ck2);
        if length(currstr)==1
          csidx_str{ck2}=['0',currstr];
        else
          csidx_str{ck2}=currstr;
        end;
      end;
      set(handles.CurrStepPopUp,'String',csidx_str);
      
      cidx=newnetry_idx;        %default on new entry step
      set(handles.CurrStepPopUp,'Value',cidx);    
      ctmp = data.step_cellarr.stepidx{cidx}{1};
      if ctmp(1) == '-'
        volstr = ctmp(2:end);       %remove negative sign for volume value
        set(handles.WithRadioBut,'Value',1.0);   %set withdraw flow direction
      else
        volstr = ctmp;
        set(handles.InfusRadioBut,'Value',1.0);  %set infuse flow direction
      end;
      set(handles.VolDisp,'String',volstr);
      set(handles.RateDisp,'String',data.step_cellarr.stepidx{cidx}{2});
      set(handles.DelayMinDisp,'String',data.step_cellarr.stepidx{cidx}{3});
      set(handles.DelaySecDisp,'String',data.step_cellarr.stepidx{cidx}{4});
    else
      display('ERROR: Exceeded 99 step limit.');
    end;
    
  end;  %end button enabled "if"
end;   %end GUI exists "if"
