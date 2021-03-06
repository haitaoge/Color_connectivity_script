function jobs = do_specify_second_level_stat(sff,params,jobs)

nbjobs = length(jobs) + 1;

if isfield(params,'logfile')
  logmsg(params.logfile,'Specifying models.');
end


for i=1:length(sff)

  jobs{nbjobs}.stats{i}.factorial_design.des.t1.scans =  cellstr(sff{i});
  
  jobs{nbjobs}.stats{i}.factorial_design.masking.im = 1; % implicit masking
  jobs{nbjobs}.stats{i}.factorial_design.masking.tm.tm_none = [];

  % threshold masking
  switch parameters.explicit_mask
    case 'group_mask_mean'
      jobs{nbjobs}.stats{i}.factorial_design.masking.em = cellstr(fullfile(rfxdir,'groupmask.img'));
    case 'gray_template'
      [p]=fileparts(which('spm')) ;
      tt = fullfile(p,'tpm','grey.nii');
      jobs{nbjobs}.stats{i}.factorial_design.masking.em = cellstr(tt);
      
    otherwise
      if exist(parameters.explicit_mask)
	jobs{nbjobs}.stats{i}.factorial_design.masking.em = cellstr(parameters.explicit_mask);
      else
	error('do not find %s',parameters.explicit_mask);
      end
  end
  
  jobs{nbjobs}.stats{i}.factorial_design.dir = cellstr(fullfile(rfxdir,params.namecon{i}));

end

