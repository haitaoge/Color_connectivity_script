function [ymean ystd]=extract_roi_data2(P,roi_p)

if ~exist('P')
  P = spm_select([1 Inf],'image','select images','',pwd);
end

if ~exist('roi_p')
  roi_p = spm_select([1 Inf],'*','select roi','',pwd);
end

if iscell(P)
  P=char(P);
end

if iscell(roi_p)
  roi_p = char(roi_p);
end



vol = spm_vol(P);

for nr=1:size(roi_p,1)
  if ~ischar(roi_p(1))
     roi = roi_p(nr);
  else
     roi= maroi('load', roi_p(nr,:));
  end

  for nbv = 1:length(vol)
    yy = get_marsy(roi, vol(nbv), 'mean');
    sy=struct(yy)  ;
    ymean(nbv,nr) = mean(sy.y_struct.regions{1}.Y);
    ystd(nbv,nr) = std(sy.y_struct.regions{1}.Y);
  end
  
end
