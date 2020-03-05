function job = do_fsl_merge(fo,outname,par)

if ~exist('par'),par ='';end
defpar.sge=0;
defpar.software = 'fsl'; %to set the path
defpar.software_version = 5; % 4 or 5 : fsl version
defpar.jobname = 'fslmerge';
defpar.checkorient=0;

par = complet_struct(par,defpar);

if iscell(outname)
    %recursiv call
    for kk=1:length(outname)
       job(kk) = do_fsl_merge(fo{kk},outname{kk},par);
    end
    return
end

fo = cellstr(char(fo));

cmd = sprintf('fslmerge -t %s ',outname);

%check vol info
if par.checkorient
for k=2:length(fo)
    if compare_orientation(fo(1),fo(k)) == 0
        error('volume %s and %s have different orientation or dimension',fo{1},fo{k})        
        %return
    end
end
end

for k=1:length(fo)    
  cmd = sprintf('%s %s',cmd,fo{k});
end

job = {cmd};

do_cmd_sge(job,par);

