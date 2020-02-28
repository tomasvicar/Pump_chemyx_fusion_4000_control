%Function:              chkNterm_link
%Version:               0.1
%
%Date:                  22Aug2016
%Company:               Chemyx, Inc.
%
%Software Developer:    HTCV Information, LLC
%                       htcveng@gmail.com
%Author:                William Copeland
%
%Description:           New function to check status and conditionally 
%                       terminate data link.
%
%Inputs:
%  DLhandle             RS232 data link handle
%  GUIhandle            GUI handle
%Outputs:
%  retstat              Function return status

function [retstat] = chkNterm_link(DLhandle,GUIhandle)
retstat=0;      
DTRstr = get(DLhandle,'DataTerminalReady');
if (findstr(DTRstr,'off'))
  display('ERROR: lost data link connection. Shutting down.');
  data = get(GUIhandle,'UserData');
  delete(data.cleanupobj);
  closereq;
  retstat=1;            %to indicate GUI shutdown
end;


  
            