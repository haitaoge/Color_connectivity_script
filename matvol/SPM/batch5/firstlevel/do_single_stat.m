

switch action
    
    %- Delete previous SPM.mat
    %----------------------------------------------------------------------
    case 'deletefiles'
        logmsg(logfile,'Deleting previous analysis...');
        fls = {'^SPM.mat$','^mask\..{3}$','^ResMS\..{3}$','^RPV\..{3}$',...
            '^beta_.{4}\..{3}$','^con_.{4}\..{3}$','^ResI_.{4}\..{3}$',...
            '^ess_.{4}\..{3}$', '^spm\w{1}_.{4}\..{3}$'};
        
        for i=1:length(fls)
            j = spm_select('List',statdir,fls{i});
            for k=1:size(j,1)
                spm_unlink(fullfile(statdir,deblank(j(k,:))));
            end
        end
        
        
        %- Model specification
        %----------------------------------------------------------------------
    case 'specify'
        
        logmsg(logfile,'Model Specification...');
        nbjobs = nbjobs + 1;
        
        timing.units   = 'secs';
        timing.RT      = params.TR;
        
        if isstruct(params.microtime)
            timing.fmri_t  = parameters.microtime.t;
            timing.fmri_t0 = parameters.microtime.t0;
            
        else
            
            switch  params.microtime
                case 'default'
                    timing.fmri_t  = 16;
                    timing.fmri_t0 = 1;
                case 'slicetimed'
                    %find the number of slice of the raw data (ie : whithout r s w a)
                    [ffp,fff,ffe]=fileparts(files{1}(1,:));
                    erase_lettre = strcmp(fff(1),'r')|strcmp(fff(1),'s')|strcmp(fff(1),'w')|strcmp(fff(1),'a');
                    while (erase_lettre)
                        fff(1) = [];
                        erase_lettre = strcmp(fff(1),'r')|strcmp(fff(1),'s')|strcmp(fff(1),'w')|strcmp(fff(1),'a');
                    end
                    
                    V = spm_vol(fullfile(ffp,[fff,ffe]));
                    
                    [slice_order,ref_slice] = get_slice_order(params,V.dim(3));
                    
                    timing.fmri_t  = length(slice_order);
                    timing.fmri_t0 = find(slice_order==ref_slice);
                otherwise
                    error('Please define parameter.microtime in your parmas file');
            end
        end
        
        
        
        jobs{nbjobs}.stats{1}.fmri_spec.timing = timing;
        jobs{nbjobs}.stats{1}.fmri_spec.dir = cellstr(statdir);
        
        if isfield(parameters,'global_scaling')
            jobs{nbjobs}.stats{1}.fmri_spec.global = parameters.global_scaling;
        end
        
        switch lower(params.bases.type)
            case 'hrf'
                jobs{nbjobs}.stats{1}.fmri_spec.bases.hrf.derivs = [0 0];
            case 'hrf+deriv'
                jobs{nbjobs}.stats{1}.fmri_spec.bases.hrf.derivs = [1 0];
            case 'hrf+2derivs'
                jobs{nbjobs}.stats{1}.fmri_spec.bases.hrf.derivs = [1 1];
            case 'fir'
                jobs{nbjobs}.stats{1}.fmri_spec.bases.fir = ...
                    struct('length',params.bases.length,'order',params.bases.order);
            case 'fourier'
                jobs{nbjobs}.stats{1}.fmri_spec.bases.fourier = ...
                    struct('length',params.bases.length,'order',params.bases.order);
            otherwise
                error('Unknown basis function');
        end
        
        nbsess = length(files);
        
        for i=1:nbsess
            jobs{nbjobs}.stats{1}.fmri_spec.sess(i).scans = cellstr(files{i});
            jobs{nbjobs}.stats{1}.fmri_spec.sess(i).hpf = params.HF_cut;
            
            if isfield(params,'onset_matfile')
                
                %jobs{nbjobs}.stats{1}.fmri_spec.sess(i).multi = onset_def_file(i);
                %either the preciding line or the next if you want to see the onset in your design
                oofile = fullfile(params.subjectdir,params.onset_matfile{i});
                if ~exist(oofile)
                    dd=dir(oofile);
                    if length(dd)==1
                        oofile = fullfile(fileparts(oofile),dd.name);
                    end
                end
                
                l = load(oofile);
                cond='';
                for kk=1:length(l.names)
                    cond(kk).name = l.names{kk};
                    cond(kk).onset = l.onsets{kk};
                    cond(kk).duration = l.durations{kk};
                    
                    if isfield(l,'pmod')
                        %ATTENTION avant : cond(kk).pmod = l.pmod{kk};
                        
                        %si autre format
                        if length(l.pmod)>=kk
                            
                            ppmod = l.pmod(kk);
                            if iscell(ppmod), ppmod=ppmod{1}; end
                            
                            if length(ppmod.name)==0
                                pmod =  struct('name', {}, 'param', {}, 'poly', {});
                            end
                            
                            for nbp=1:length(ppmod.name)
                                if isempty(ppmod.name{nbp})
                                    pmod =  struct('name', {}, 'param', {}, 'poly', {});
                                else
                                    pmod(nbp).name = ppmod.name{nbp};
                                    pmod(nbp).param = ppmod.param{nbp};
                                    pmod(nbp).poly = ppmod.poly{nbp};
                                end
                            end
                            
                            cond(kk).pmod = pmod;
                        end
                        
                    end
                    
                    if isfield(l,'mod')
                        cond(kk).pmod = l.mod{kk};
                    end
                    
                    if isfield(l,'tmod')
                        if iscell(l.tmod),  cond(kk).tmod = l.tmod{kk};end
                    end
                    
                end
                if isfield(params,'reg_skip')
                    cond(params.reg_skip{i})=[];
                end
                
                jobs{nbjobs}.stats{1}.fmri_spec.sess(i).cond = cond;
            end
            
            if isfield(params,'onset')
                jobs{nbjobs}.stats{1}.fmri_spec.sess(i).cond = params.onset{i};
            end
            
            if isfield(params,'user_regressor')
                if isfield(params.user_regressor,'matfile')
                    
                    user_regressor = fullfile(params.subjectdir,params.user_regressor.matfile{i});
                    
                    if ~exist(user_regressor)
                        dd=dir(user_regressor);
                        if length(dd)==1
                            user_regressor = fullfile(fileparts(user_regressor),dd.name);
                        else
                            error('can not find a file for %s',user_regressor);
                        end
                    end
                    
                    jobs{nbjobs}.stats{1}.fmri_spec.sess(i).multi_reg = cellstr(user_regressor);
                    
                elseif isfield(params.user_regressor,'regress')
                    user_reg = params.user_regressor.regress{i};
                    jobs{nbjobs}.stats{1}.fmri_spec.sess(i).regress = user_reg;
                end
            end
            
            if params.rp
                %append mvt param as user_regressor
                if exist('user_reg'), nbr= length(user_reg);
                else	  nbr=0;	end
                                
                concat_rp = 0;
                if isfield(params,'concat_series')
                    if params.concat_series
                        concat_rp=1;
                    end
                end
                if concat_rp
                    reg_mvt = [];
                    for nnn = 1:length(rp)
                        reg_mvt_ser = load(rp{nnn});
                        if isfield(params,'skip')
                            reg_mvt_ser(params.skip{i},:)=[];
                        end
                        reg_mvt = cat (1,reg_mvt,reg_mvt_ser);
                    end
                else
                    
                    reg_mvt = load(rp{i});
                    if isfield(params,'skip')
                        reg_mvt(params.skip{i},:)=[];
                    end
                end
                
                
                for rc = 1:size(reg_mvt,2)
                    nbr=nbr+1;
                    user_reg(nbr).name = ['mvt' num2str(rc)];
                    user_reg(nbr).val = reg_mvt(:,rc);
                end
                
                jobs{nbjobs}.stats{1}.fmri_spec.sess(i).regress = user_reg;
                clear user_reg;
            end
        end
        
        if isfield(params,'first_level_explicit_mask')
            jobs{nbjobs}.stats{1}.fmri_spec.mask = cellstr(params.first_level_explicit_mask);
        end
        
        if isfield(params,'first_level_factors')
            jobs{nbjobs}.stats{1}.fmri_spec.fact = params.first_level_factors;
        end
        
        
        %- Model estimation
        %----------------------------------------------------------------------
    case 'estimate'
        logmsg(logfile,'Model Estimation...');
        nbjobs = nbjobs + 1;
        jobs{nbjobs}.stats{1}.fmri_est.spmmat = cellstr(fullfile(statdir,'SPM.mat'));
        
        
        %- Delete previous contrasts
        %----------------------------------------------------------------------
    case 'deletecontrasts'
        logmsg(logfile,'Contrasts Deletion...');
        
        nbjobs = nbjobs + 1;
        jobs{nbjobs}.stats{1}.con.spmmat = cellstr(fullfile(statdir,'SPM.mat'));
        jobs{nbjobs}.stats{1}.con.delete = 1;
        
        
        %- Contrasts specification
        %----------------------------------------------------------------------
    case 'contrasts'
        logmsg(logfile,'Contrasts Specifications...');
        nbjobs = nbjobs + 1;
        
        if isfield(params.contrast,'values')
            names = params.contrast.names;
            values = params.contrast.values;
            types = params.contrast.types;
            
        elseif isfield(params.contrast,'string_def')
            [names, values, types] = setContrastsFromOnsetMatfiles(params);
            
        elseif isfield(params.contrast,'mfile')
            
            evalstr = ['[names, values,types] = ' params.contrast.mfile ';'];
            eval(evalstr);
            
        end
        
        
        %- Adding 'Effect of interest' F-test
        %names = {'Effects of interest' names{:}};
        %nbc =
        %values = {eye(nbc) values{:}};
        
        jobs{nbjobs}.stats{1}.con.spmmat = cellstr(fullfile(statdir,'SPM.mat'));
        for i=1:length(names)
            switch types{i}
                case 'T'
                    jobs{nbjobs}.stats{1}.con.consess{i}.tcon.name = names{i};
                    jobs{nbjobs}.stats{1}.con.consess{i}.tcon.convec = values{i};
                    %jobs{nbjobs}.stats{1}.con.consess{i}.tcon.sessrep = 'none';
                case 'F'
                    jobs{nbjobs}.stats{1}.con.consess{i}.fcon.name = names{i};
                    for j=1:size(values{i},1)
                        jobs{nbjobs}.stats{1}.con.consess{i}.fcon.convec{j} = values{i}(j,:);
                    end
                    %jobs{nbjobs}.stats{1}.con.consess{i}.fcon.sessrep = 'none';
            end
        end
        
        if isfield (params.contrast,'delete_previous')
            if params.contrast.delete_previous
                jobs{nbjobs}.stats{1}.con.delete = 1;
            end
        end
        
        
        
        %- Display results
        %----------------------------------------------------------------------
    case 'results'
        logmsg(logfile,'Display results...');
        nbjobs = nbjobs + 1;
        
        jobs{nbjobs}.stats{1}.results.spmmat = cellstr(fullfile(statdir,'SPM.mat'));
        jobs{nbjobs}.stats{1}.results.print  = 1;
        jobs{nbjobs}.stats{1}.results.conspec.title = ''; % determined automatically if empty
        jobs{nbjobs}.stats{1}.results.conspec.contrasts = Inf; % Inf for all contrasts
        jobs{nbjobs}.stats{1}.results.conspec.threshdesc = params.report.type;
        jobs{nbjobs}.stats{1}.results.conspec.thresh = params.report.thresh;
        jobs{nbjobs}.stats{1}.results.conspec.extent = params.report.extent;
        
        
        %- Send an email
        %----------------------------------------------------------------------
    case 'sendmail'
        logmsg(logfile,'Send email...');
        nbjobs = nbjobs + 1;
        
        jobs{nbjobs}.tools{1}.sendmail.recipient = 'antoinette.jobert@cea.fr';
        jobs{nbjobs}.tools{1}.sendmail.subject = '[SPM] [%DATE%] On behalf of SPM5';
        jobs{nbjobs}.tools{1}.sendmail.message = 'Hello from SPM!';
        jobs{nbjobs}.tools{1}.sendmail.attachments = {fullfile(statdir, ...
            ['spm_' datestr(now,'yyyy') datestr(now,'mmm') datestr(now,'dd') '.ps'])};
        jobs{nbjobs}.tools{1}.sendmail.params.smtp = 'mx.intra.cea.fr';
        jobs{nbjobs}.tools{1}.sendmail.params.email = 'guillaume.flandin@cea.fr';
        jobs{nbjobs}.tools{1}.sendmail.params.zip = 'Yes';
        
        
        %- Save and Run job
        %----------------------------------------------------------------------
    case 'run'
        logmsg(logfile,sprintf('Job batch file saved in %s.',fullfile(statdir,'jobs_model.mat')));
        
        d=dir(fullfile(statdir,'jobs_model*.*'));
        
        if ~isempty(d)
            savexml(fullfile(statdir,['jobs_model',num2str(length(d)+1),'.xml']),'jobs');
        else
            savexml(fullfile(statdir,'jobs_model.xml'),'jobs');
        end
        
        spm_jobman('run',jobs);
        
    case 'run_dist'
        
        
        d=dir(fullfile(statdir,'jobs_model*.*'));
        
        jname =fullfile(statdir,['jobs_model'])
        
        if ~isempty(d)
            jname = [jname,num2str(length(d)+1),'.xml'];
        else
            jname = [jname,'.xml'];
        end
        
        logmsg(logfile,sprintf('Job batch file saved in %s.',jname));
        
        savexml(jname,'jobs');
        
        if ~exist('job_to_distrib')
            job_to_distrib={};
        end
        
        job_to_distrib{end+1} = jname;
        
    case 'display'
        
        if ~exist('all_job')
            all_job=jobs;
        else
            all_job = [all_job,jobs];
        end
        
        %      spm_jobman('interactive',jobs);
        %      spm('show');
end
