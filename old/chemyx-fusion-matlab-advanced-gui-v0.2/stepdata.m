%Class:                 stepdata
%Version:               0.1
%
%Date:                  29Aug2016
%Company:               Chemyx, Inc.
%
%Software Developer:    HTCV Information, LLC
%                       htcveng@gmail.com
%Author:                William Copeland
%
%Description:           New class for step parameter storage.

classdef stepdata
  properties
    stepidx;
  end
  methods
    function obj = stepdata(nelem)
      obj.stepidx = cell(nelem,1);
    end
    function delete(obj)
      delete(obj);
      clear obj;
    end
  end
end
  
            