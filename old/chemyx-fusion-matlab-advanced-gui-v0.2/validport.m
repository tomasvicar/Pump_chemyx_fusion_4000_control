%Function:              validport.m
%Version:               0.1
%
%Date:                  24Aug2016
%Company:               Chemyx, Inc.
%
%Software Developer:    HTCV Information, LLC
%                       htcveng@gmail.com
%Author:                William Copeland
%
%Description:           New function to validate available COM ports.
%
%Inputs:
%   selcom_str          Selected port, string
%   availports          Available ports, cell array
%
%Outputs:
%   validchk            String compare results     

function [validchk] = validport(selcom_str,availports)
[numelem junk] = size(availports);
availportstr=[];
for i=1:numelem
  availportstr = [availportstr; availports{i}];
end;

validchk=zeros(numelem,1);
for j=1:numelem
  validchk(j)=~isempty(findstr(selcom_str,availportstr(j,:)));
end;
            