function dti_import(dti_files,outdir,par)
%function dti_import(dti_files,bval_f,bvec_f,outdir,par)

if ~exist('par')
    par='';
end



if ~isfield(par,'skip_vol'),  par.skip_vol=''; end

if ~isfield(par,'sge'),  par.sge=0; end
if ~isfield(par,'queu'),  par.queu = 'server_ondule';end
if ~isfield(par,'dirjob'),  par.dirjob = pwd ;end
if ~isfield(par,'data4D'),    par.data4D = '4D_dti';  end
if ~isfield(par,'dicom_info'), par.dicom_info = '';end
if ~isfield(par,'bvecs'), par.bvecs = '^bvecs';end
if ~isfield(par,'bvals'), par.bvals = '^bvals';end
if ~isfield(par,'swap_bvecs'), par.swap_bvecs = '';end
if ~isfield(par,'mult_bvecs'), par.mult_bvecs = '';end

if iscell(outdir)
    pp = par;
    for k=1:length(outdir)
        if iscell(pp.bvals)
            par.bvals = pp.bvals(k);
            par.bvecs = pp.bvecs(k);
        end
        dti_import(dti_files{k},outdir{k},par)
    end
    return
end

%dti_files=get_subdir_regex_files(dti_spm_dir,'^f.*img');

if iscell(par.bvals)
    bval_f = par.bvals;
    bvec_f = par.bvecs;
else
    dti_spm_dir  =get_parent_path(dti_files);
    bval_f = get_subdir_regex_files(dti_spm_dir,'bvals',1);
    bvec_f = get_subdir_regex_files(dti_spm_dir,'bvecs',1);
end

dti_files = char(dti_files);

%remove skiping volume
if ~isempty(par.skip_vol)
    dti_files(par.skip_vol,:)='';
end

if ~exist(outdir)
    mkdir(outdir)
end

if par.sge
    type='fsl_import';
    
    p.verbose=0;
    ff = get_subdir_regex_files(par.dirjob,type,p);
    if isempty(ff)
        numjob=1;
    else
        numjob=size(ff{1},1)+1;
    end
    
    jname = fullfile(par.dirjob,sprintf('%s_job_%.3d',type,numjob) );
    jname_err = [jname '_err.log'];  jname_log = [jname '_log.log'];
    
    fj = fopen(jname,'w+');
    fprintf(fj,'#$ -S /bin/bash \n source /usr/cenir/bincenir/fsl_path2; \n  ');
    fprintf(fj,'cd %s\n',outdir);
    
else
    cwd = pwd;
    cd(outdir)
end


%DO MERGE
cmd =sprintf(' fslmerge  -t %s ',par.data4D);

for k=1:size(dti_files,1)
    cmd = [cmd ' ' dti_files(k,:) ];
end

if par.sge
    fprintf(fj,cmd);fprintf(fj,'\n');
else
    unix(cmd)
end


bval=[];bvec=[];
for k=1:length(bval_f)
    aa = load(deblank(bval_f{k}));
    bb = load(deblank(bvec_f{k}));
    bval = [bval aa];
    bvec = [bvec,bb];
end

%remove skiping volume
if ~isempty(par.skip_vol)
    bval(:,par.skip_vol)=[];
    bvec(:,par.skip_vol)=[];
end


if ~isempty(par.dicom_info)
    fid = fopen(fullfile(outdir,'acqp.txt'),'w');
    for k = 1:length(par.dicom_info)
        h = par.dicom_info(k);
        hsession(k) = h.SeriesNumber;        
        phase_angle = str2num(h.phase_angle);
        if isempty(phase_angle), phase_angle = 0;end
        switch h.PhaseEncodingDirection
            case 'COL '
                if phase_angle<0.1
                    fprintf(fid,'0 -1 0 0.050\n');
                elseif abs(phase_angle-pi)<0.1
                    fprintf(fid,'0 1 0 0.050\n');
                else
                    error('what is the Y phase direciton <%f> in you  dicom!',phase_angle)
                end
            case 'ROW '
                if abs(phase_angle-pi/2)<0.1
                    fprintf(fid,'-1 0 0 0.050\n');
                elseif abs(phase_angle+pi/2)<0.1
                    fprintf(fid,'1 0 0 0.050\n');
                else
                    error('what is the phase direciton in you fucking dicom!')
                end
                
            otherwise
                error('what is this phase axe <%s>', h.PhaseEncodingDirection)
        end
        
    end
    
    fclose(fid);
    [aa bb cc]= unique(hsession);
    fid = fopen(fullfile(outdir,'session.txt'),'w');
    fprintf(fid,'%d ',cc);
    fclose(fid);
    
    fid = fopen(fullfile(outdir,'index.txt'),'w');
    fprintf(fid,'%d ',1:length(par.dicom_info));
    fclose(fid);
 
end
%Writing bvals and bvec
if (~isempty(par.swap_bvecs))
    bvec = bvec(par.swap_bvecs,:);    
end

if (~isempty(par.mult_bvecs))
    bvec = bvec .* repmat(par.mult_bvecs',1,size(bvec,2));
end

fid = fopen(fullfile(outdir,'bvals'),'w');
fprintf(fid,'%d ',bval);  fprintf(fid,'\n');  fclose(fid);

fid = fopen(fullfile(outdir,'bvecs'),'w');
for kk=1:3
    fprintf(fid,'%f ',bvec(kk,:));
    fprintf(fid,'\n');
end
fclose(fid);



if par.sge
    fclose(fj);
    fprintf('writing job %s\n',jname);
    
    qsubname = fullfile(par.dirjob,'do_qsub.sh');
    
    if ~exist(qsubname)
        fqsub = fopen(qsubname,'w+');
        fprintf(fqsub,'source /usr/cenir/sge/default/common/settings.sh \n');
        
    else
        fqsub = fopen(qsubname,'a+');
    end
    
    fprintf(fqsub,'qsub -q %s -o %s -e %s %s\n',par.queu,jname_log,jname_err,jname);
    
    fclose(fqsub);
    
    unix(['chmod +x  ' qsubname]);
    
else
    cd(cwd)
end

