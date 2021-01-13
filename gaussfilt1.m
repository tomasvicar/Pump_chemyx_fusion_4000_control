function [signal] = gaussfilt1(signal,sigma)


mask_half = ceil(3*sigma);
se = normpdf([-mask_half:mask_half],0,sigma);
signal = conv(padarray(signal,[mask_half,0],'symmetric'), se,'valid');



end


