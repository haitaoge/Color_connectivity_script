function  matlabbatch = job_dartel_to_MNI(temp,flow,img,par)

if ~exist('par')
  par='';
end

if ~isfield(par,'preserve')
  par.preserve=0; %no modulation
end

if ~isfield(par,'fwhm')
  par.fwhm=[8 8 8]; %no modulation
end
if ~isfield(par,'vox')
  par.vox=[NaN NaN NaN]; %no modulation
end
if ~isfield(par,'bb')
  par.bb=[NaN NaN NaN
          NaN NaN NaN];
end


if ~iscell(temp)
  temp = cellstr(temp);
end
if ~iscell(flow)
  flow = cellstr(flow);
end
if ~iscell(img)
  img = cellstr(img);
end

%-----------------------------------------------------------------------
% Job configuration created by cfg_util (rev $Rev: 3357 $)
%-----------------------------------------------------------------------
for k=1:length(flow)
	ff = cellstr(char(img(k)));

matlabbatch{1}.spm.tools.dartel.mni_norm.template = temp;
matlabbatch{1}.spm.tools.dartel.mni_norm.data.subj(k).flowfield = flow(k);
matlabbatch{1}.spm.tools.dartel.mni_norm.data.subj(k).images = ff;

matlabbatch{1}.spm.tools.dartel.mni_norm.vox = par.vox;
matlabbatch{1}.spm.tools.dartel.mni_norm.bb = par.bb;
matlabbatch{1}.spm.tools.dartel.mni_norm.preserve = par.preserve;
matlabbatch{1}.spm.tools.dartel.mni_norm.fwhm = par.fwhm ;
end
