function [job f_do_qsubar] = do_cmd_sge(job,par,jobappend,qsubappend)


if ~exist('par'),  par=''; end
if ~exist('jobappend','var'), jobappend ='';end
if ~exist('qsubappend','var'), qsubappend ='';end

def_par.jobname='jobname';
def_par.software = '';%fsl freesurfer
def_par.software_version = '';
def_par.software_path = '';

def_par.jobdir=pwd;
def_par.sge=1;
def_par.sge_queu = 'long';
def_par.job_append = 1;
def_par.sge_nb_coeur=1;
def_par.submit_sleep = 1;  %add a sleep of 1 second between each qsub
def_par.fake = 0;
def_par.walltime = ''; % syntax slurm -t [min] OR -t [days-hh:mm:ss]
def_par.qsubappend = '';
def_par.mem = 4000;  %give a number in Mega --mem=[mem][M|G|T] OR --mem-per-cpu=[mem][M|G|T]
def_par.job_pack = 1;
def_par.sbatch_args = '--export=NONE -m block:block ';

par = complet_struct(par,def_par);

if isfield(par,'nb_thread')
    par.sge_nb_coeur = par.nb_thread;
end

if isstr(par.mem)
    par.mem = str2num(par.mem);
end


%convert walltime
if ~isempty(par.walltime)
    hh = str2num(par.walltime(1:2));
    dday = fix(hh/24);
    hh = rem(hh,24);
    par.walltime = sprintf('%d-%.2d%s',dday,hh,par.walltime(3:end));
end


if ~isempty(jobappend)
    if length(job)~=length(jobappend)
        error('job and jobappend have different size')
    end
    
    for kk=1:length(job)
        job{kk} = sprintf('%s\n\n%s',jobappend{kk},job{kk});
    end
end

if par.sge == -1
    return
end

if par.job_pack>1;
    jnew={};
    for nn=1:par.job_pack:length(job)
        kkkend = nn+par.job_pack-1;
        if kkkend>length(job)
            kkkend=length(job);
        end
        aa = job{nn};
        for kkk=nn+1:kkkend
            aa = [aa, job{kkk}];
        end
        jnew(end+1)={aa};
    end
    job=jnew;
end

%make jobdir in a subdir with jobname
par.jobdir = fullfile(par.jobdir,par.jobname);

if par.sge==0
    for nn=1:length(job)
        cmd = job{nn};
        if nn<3 || nn>(length(job)-3)
            fprintf('runing %s \n\n',cmd);
        end
        if par.fake,    else    unix(cmd);        end
    end
    
else
    
    job_dir = par.jobdir;
    
    if ~exist(job_dir)
        mkdir(job_dir);
    end
    
    
    % unix('source /usr/cenir/sge/default/common/settings.sh ')
    
    fprintf('\n writing %d job for the grid engin in %s \n',length(job),job_dir);
    
    f_do_qsub=fullfile(job_dir,'do_qsub_sge.sh');
    if ~isempty(qsubappend)
        f_do_qsubar=qsubappend;
        fqsubar=fopen(f_do_qsubar,'a');
        fprintf(fqsubar,'\n');

    else
        f_do_qsubar=fullfile(job_dir,'do_qsub.sh');
        fqsubar=fopen(f_do_qsubar,'w');
    end
    
    
    f_do_array=fullfile(job_dir,'do_job_array.sh');
    f_do_loc=fullfile(job_dir,'do_all_local.sh');
    
    if par.job_append
        fqsub=fopen(f_do_qsub,'a');        
        floc=fopen(f_do_loc,'a');
    else
        fqsub=fopen(f_do_qsub,'w');        
        floc=fopen(f_do_loc,'w');
    end
    
    if par.job_append
        %dd=dir([job_dir '/*' par.jobname '*']);
        dd=get_subdir_regex_files(job_dir,['^j.*' par.jobname],struct('verbose',0));if ~isempty(dd),dd = cellstr(char(dd));end
        kinit = length(dd);
    else
        kinit = 0;
    end
    
    for k=1:length(job)
        
        cmdd = job{k};
        
        % it is not usefule if already well define in your .bashrc in case you need
        if ~isempty(par.software_path)
            cmdd = sprintf('%s\n%s',par.software_path,cmdd);
        end
        
        jname = sprintf('j%.2d_%s',k+kinit,par.jobname);
        
        fpn = fullfile(job_dir,jname);
        fpnlog = sprintf('%s.log',fpn);
        fpnlogerror = sprintf('%s.err',fpn);
        
        ff=fopen(fpn,'w');
        switch par.sge_queu
            case {'server_ondule','server_irm'}
                fprintf(ff,'#$ -S /bin/bash \n');
                fprintf(ff,cmdd);
                fclose(ff);
                
            otherwise
                fprintf(ff,'#!/bin/bash\n');
                
                %fprintf(ff,'',);
                fprintf(ff,cmdd);
                
                fclose(ff);
        end
        
        switch par.sge_queu
            case {'server_ondule','server_irm'}
                
                cmd{k} = sprintf('qsub -V -q %s %s -o %s -e %s %s',par.sge_queu,par.qsubappend,fpnlog,fpnlogerror,fpn);
                fprintf(fqsub,'%s\n sleep %d \n',cmd{k},par.submit_sleep);
        end
        
        
        fprintf(floc,'bash %s > log_%s 2> err_%s \n',fpn,jname,jname);
        
    end
    
    fclose(fqsub);fclose(floc);
    
    
    fprintf(fqsubar,'export jobid=`sbatch -p %s -N 1 --cpus-per-task=%d --job-name=%s %s ',par.sge_queu,par.sge_nb_coeur,par.jobname,par.qsubappend);
    if ~isempty(par.walltime)
        fprintf(fqsubar,' -t %s',par.walltime);
    end
    if ~isempty(par.mem),        fprintf(fqsubar,' --mem=%d',par.mem);    end
    if ~isempty(qsubappend),        fprintf(fqsubar,'  --depend=afterok:$jobid ');    end
    
    fprintf(fqsubar,' %s ',par.sbatch_args);
    
    if ~isempty(qsubappend)
        fprintf(fqsubar,' -o %s/log-%%A_%%a  -e %s/err-%%A_%%a  --array=%d %s |awk ''{print $4}''` \necho submitted job $jobid\n',job_dir,job_dir,k+kinit,f_do_array);
    else
        fprintf(fqsubar,' -o %s/log-%%A_%%a  -e %s/err-%%A_%%a  --array=1-%d %s |awk ''{print $4}''` \necho submitted job $jobid\n',job_dir,job_dir,k+kinit,f_do_array);
    end
    fclose(fqsubar);
    
    fffa = fopen(f_do_array,'w');
    fprintf(fffa,'#!/bin/bash\n');
	fprintf(fffa,'\n\necho started on $HOSTNAME \n date\n\n');
    fprintf(fffa,'tic="$(date +%%s)"\n\n');
    
    fprintf(fffa,' cmd=$( printf "j%%02d_%s" ${SLURM_ARRAY_TASK_ID})\n bash %s/$cmd\n\n',par.jobname,job_dir);
    fprintf(fffa,'\n\ntoc="$(date +%%s)";\nsec="$(expr $toc - $tic)";\nmin="$(expr $sec / 60)";\nheu="$(expr $sec / 3600)";\necho Elapsed time: $min min $heu H\n');
    fclose(fffa);
    
    cmdout=sprintf('bash %s',f_do_qsub);
    
    if strfind(par.jobname,'dti_bedpostx')
        fprintf('\n warning RUN without qsub because bedpostx calls qsub\n');
        cmdout=sprintf('bash %s',f_do_loc);
        delete(f_do_qsub)
    end
end

%--depend=afterok:343599 
