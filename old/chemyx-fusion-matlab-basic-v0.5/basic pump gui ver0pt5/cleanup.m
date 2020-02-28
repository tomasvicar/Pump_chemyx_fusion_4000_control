%Class:                 cleanup
%Version:               0.1
%
%Date:                  19Aug2016
%Company:               Chemyx, Inc.
%
%Software Developer:    HTCV Information, LLC
%                       htcveng@gmail.com
%Author:                William Copeland
%
%Description:           New cleanup class to aid with graceful GUI
%                       shutdown.

classdef cleanup
  properties
    serialFID;
  end
  methods
    function obj = cleanup(sfid)
      obj.serialFID = sfid;
    end
    
    function delete(obj)
      fclose(obj.serialFID);
      delete(obj.serialFID);
      clear obj.serialFID;
    end
  end
end
  
            