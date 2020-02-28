%Script:                pump_gui.m
%Version:               0.5 REL
%
%Date:                  11Sep2016
%Company:               Chemyx, Inc.
%
%Software Developer:    HTCV Information, LLC
%                       htcveng@gmail.com
%Author:                William Copeland
%
%Description: Basic program with GUI to control and retrieve status of
%  Chemyx Syringe Pump. Communicates through the RS232 serial interface.
%  Added datalink serial port selection input and controls, removed
%  restart button, added dynamic volume units (Ver0.2).
%  Reformatted elapsed time, implemented continuous status updating, 
%  suppressed serial port warnings, and implemented graceful USB 
%  disconnect shutdown (Ver0.3).
%  Automatically resumes updates if pump was previously running,
%  addressed residual error messages, and replaced button press handling,
%  improved COM port handling (Ver0.4).
%  Error message when no ports available, added rudimentary delay handling,
%  added baud rate selector, and reduced button press response time 
%  (Ver0.5).

function varargout = pump_gui(varargin)

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pump_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @pump_gui_OutputFcn, ...
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

% --- Executes just before pump_gui is made visible.
function pump_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for pump_gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

%add new variable so UIs can access
                 %create reference vector for RS232 receive line parsing
handles.digNperiod =['0' '1' '2' '3' '4' '5' '6' '7' '8' '9' '.'];

%set all display defaults
set(handles.PumpStatDisp,'String','Unknown');
set(handles.ElapTmDisp,'String','Unknown');
set(handles.DispensVolDisp,'String','Unknown');
set(handles.DLComPopup,'String',['COM3';'COM1']);
set(handles.TmUnitDisp,'String','HH:MM:SS');
set(handles.BaudPopUp,'String',['38400';'9600 ']);
set(handles.BaudPopUp,'Value',1.0);

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
              'pausetm',0.04,'delay_val',0);
    %ceaseupd_flg           stop display update flag
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
    %pausetm                pause time
    %delay_val              min, pump delay value
    
set(handles.figure1,'UserData',data);
data = get(handles.figure1,'UserData');

warnID='MATLAB:serial:fscanf:unsuccessfulRead';
warning('off',warnID);

set(handles.DLPanel,'FontWeight','bold');
set(handles.StatPanel,'FontWeight','bold');

guidata(hObject, handles);              %save final changes to structure

% --- Outputs from this function are returned to the command line.
function varargout = pump_gui_OutputFcn(hObject, eventdata, handles) 
% Get default command line output from handles structure
varargout{1} = handles.output;

data = get(handles.figure1,'UserData');

resumeupd_flg = 0;                     %reset flag
set(handles.figure1,'UserData',data);

%check pump status to determine proper setting for flags
fprintf(handles.s,'status');     
pause(data.pausetm);                     
out = fscanf(handles.s);
while (isempty(findstr('>',out)))
  if (isempty(out))   
    break;               
  end
  out_num = str2num(out(1));
  if (out_num==1)     %if pump already running (=1)
    data.stoponce_flg = 0;    %reset stop button flag
    resumeupd_flg = 1;   %set flag to resume updating
    data.onetimeunitupd_flg = 1;    %update units
    data.ceaseupd_flg = 0;     %reset flag for continuous updates
  elseif ((out_num==0) | (out_num==3))   %if pump stopped (=0) or
                                         %  stop/delay situation (=3)
    data.ceaseupd_flg = 1;    %don't resume cont upd
    resumeupd_flg = 1;   %set flag to resume updating
    data.onetimeunitupd_flg = 1;    %update units
    data.oneupdate_flg = 2;         %allow one last update flag
  elseif (out_num==2)   %if pump paused (=2)
    data.ceaseupd_flg = 1;    %don't resume cont upd
    data.stoponce_flg = 0;    %reset stop button flag
    resumeupd_flg = 1;   %set flag to resume updating
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
  pump_gui('UpdBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
            %resume updates
end;
            
% --- Executes on button press in StrtBut.
function StrtBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');   %update shared data
  
  if (data.DLsemaphore_flg == 0)   %see if DL available
    %if DL available then do regular processing
    pump_gui('StrtBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  else
      %otherwise capture button press for later processing, but only
      %  if start button is active
    data.startbutpress_flg = 1;       %set start button pressed flag &
    data.oneORmorebutpress_flg = 1;   %one or more buttons pressed flag
    set(handles.figure1,'UserData',data);
    
    data = get(handles.figure1,'UserData');
  end;
end;

function StrtBut_ButtonDownFcn(hObject, eventdata, handles)

[retstat] = chkNterm_link(handles.s,handles.figure1);

if (retstat == 0)      %if no DL issue
  data = get(handles.figure1,'UserData');    %get shared data

  data.ceaseupd_flg = 0;                      %(re-)activate status updating
  if data.oneupdate_flg ~= 2
    data.oneupdate_flg = 0;                   %reset one-time update flag
  end;
  data.stoponce_flg = 0;                      %clear stop once flag
  data.onetimeunitupd_flg = 1;                %one time vol unit update
  data.resetlock_flg = 1;                     %enable reset button lock
  set(handles.figure1,'UserData',data);

  data = get(handles.figure1,'UserData'); 

  out = fscanf(handles.s);           %flush buffer
  while ~isempty(out) 
    out = fscanf(handles.s);
  end
  
  fprintf(handles.s,'start');     %send command
  pause((data.delay_val*60) + 1);    %pause to give unit time to respond
                                      %  including delay consideration
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
  pump_gui('UpdBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
end;  %DL check "if"


% --- Executes on button press in StopBut.
function StopBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
  
  if (data.DLsemaphore_flg == 0)   
    pump_gui('StopBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  else    
    data.stopbutpress_flg = 1;  
    data.oneORmorebutpress_flg = 1;
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
  end;
end;


function StopBut_ButtonDownFcn(hObject, eventdata, handles)
[retstat] = chkNterm_link(handles.s,handles.figure1);

if (retstat == 0)
  data = get(handles.figure1,'UserData');

  if (data.stoponce_flg == 0)     %only continue if first press of stop

    runupdflg = 0;                  %create and initialize run update flag

    if (data.ceaseupd_flg==1)   %if ceaseupd_flg previously set by "pause",
      runupdflg = 1;            %  then set this special case flag
    end;
    
    data.resetlock_flg = 0;                 %disable reset button lock
    data.ceaseupd_flg = 1;                   %disable status update flag
    if (data.oneupdate_flg ~= 2)
      data.oneupdate_flg = 1;                  
    end;
    data.stoponce_flg = 1;                  %set stop once flag
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
    
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
      pump_gui('UpdBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    end;
  end;  %double press "if"
  
  data = get(handles.figure1,'UserData');
  data.stopbutpress_flg = 0;       %whether stop processing executed or
                                   %  user error, clear stop button press
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');
end;   %DL chk "if"


% --- Executes on button press in PausBut.
function PausBut_Callback(hObject, eventdata, handles)
if (ishandle(handles.figure1) == 1)
  data = get(handles.figure1,'UserData');
  
  if (data.DLsemaphore_flg == 0)   
    pump_gui('PausBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
  else 
    data.pausebutpress_flg = 1;  
    data.oneORmorebutpress_flg = 1;
    set(handles.figure1,'UserData',data);
    data = get(handles.figure1,'UserData');
  end;
end;


function PausBut_ButtonDownFcn(hObject, eventdata, handles)
[retstat] = chkNterm_link(handles.s,handles.figure1);

if (retstat == 0)
  data = get(handles.figure1,'UserData');

  data.ceaseupd_flg = 1;                   
  if data.oneupdate_flg ~= 2
    data.oneupdate_flg = 1;
  end;
  data.resetlock_flg = 1;
  set(handles.figure1,'UserData',data);
  data = get(handles.figure1,'UserData');

  out = fscanf(handles.s);
  while ~isempty(out)   
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
    pump_gui('QuitBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
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
uiwait(msgbox({'Chemyx Syringe Pump Controller','Version 0.5',...
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
    set(handles.s,'BaudRate',baud_dec);
    set(handles.s,'Port',com_strmx(strmx_idx,:));   %update serial settings
  
    fopen(handles.s);               %re-open serial port with new settings
    
    pause(3.0);       %pause to give system time to reset
    
    out = fscanf(handles.s);
    while ~isempty(out)           %purge buffer before procede
      out = fscanf(handles.s);
    end
    
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


function VolUnitDisp_Callback(hObject, eventdata, handles)


function VolUnitDisp_CreateFcn(hObject, eventdata, handles)
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
      pump_gui('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
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
      pump_gui('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
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
      pump_gui('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
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
      pump_gui('Service_ButPress_ButtonDownFcn',hObject,eventdata,guidata(hObject));
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
      pump_gui('StopBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    elseif (data.pausebutpress_flg == 1)
      pump_gui('PausBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
    elseif (data.quitbutpress_flg == 1)
      pump_gui('QuitBut_ButtonDownFcn',hObject,eventdata,guidata(hObject));
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


function BaudPopUp_Callback(hObject, eventdata, handles)


function BaudPopUp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
