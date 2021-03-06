%this script 
 suj = get_subdir_regex('/servernas/images4/rosso/CRAISI')

stat_dir = get_subdir_regex(suj,'stats','modelromain')

voicon.contrast = 4; %contrast number
voicon.thrdesc='none'; % correction %or 'FWE'
voicon.thresh = 0.001; %seuil
voicon.extent = 0 ;  %cluster size
voicon.title = 'contrast 2';

template_path = '/usr/cenir/SPM/spm8/toolbox/wfu_pickatlas/MNI_atlas_templates/aal_MNI_V4.nii';

label = {[19 20], [19],[20]};
roiname = {'SMA','sma_droit','sma_gauche'} % a verifier lequel est gauche

csvfname = '/lena13/home_users/users/rosso/result_roi.csv';



for nbsuj = 1:length(stat_dir)
    
    cd(stat_dir{nbsuj})
    
    % DISPLAY THE MOTION CONTRAST RESULTS
    %---------------------------------------------------------------------
    clear jobs
    [pspm]=fileparts(which('spm')) ;
    
    jobs{1}.stats{1}.results.spmmat = cellstr(fullfile(stat_dir{nbsuj},'SPM.mat'));
    jobs{1}.stats{1}.results.conspec(1).titlestr = voicon.title;
    jobs{1}.stats{1}.results.conspec(1).contrasts = voicon.contrast;
    jobs{1}.stats{1}.results.conspec(1).threshdesc = voicon.thrdesc;
    jobs{1}.stats{1}.results.conspec(1).thresh = voicon.thresh;
    jobs{1}.stats{1}.results.conspec(1).extent = voicon.extent;
    jobs{1}.stats{1}.results.print = 0;
    
    spm_jobman('run',jobs);        
    
    vspm = xSPM.Vspm;
    sp=mars_space(vspm)
    rspm = maroi_pointlist(struct('mat',vspm.mat,'XYZ',xSPM.XYZ),'vox')
    rspm = spm_hold(rspm,0)
    
    rspmm=maroi_matrix(rspm,sp)

    vaal=spm_vol(template_path);


    for nbl=1:length(label)
        ll = label{nbl};
        exp = sprintf('img==%d',ll(1));
        for kk=2:length(ll)
            exp = sprintf('%s | img==%d',exp,ll(kk));
        end
        
        raal = maroi_image(struct('vol',vaal,'binarize',1,'func',exp));
        raal = spm_hold(raal,0);
        
        raalm = maroi_matrix(raal,sp);

        rr  = raalm & rspmm;
        rrm = maroi_matrix(rr,sp);
        
        volu(nbsuj,nbl) = volume(rrm);
        tval(nbsuj,nbl) = mean(getdata(rrm,xSPM.Vspm)) ;
               
        
    end
        
end

[p sujn] = get_parent_path(stat_dir,3)
ff = fopen(csvfname,'a+')

fprintf(ff,'\nSuj')
for k = 1:length(roiname)
    fprintf(ff,',%s_nbvox',roiname{k});
end
for k=1:length(sujn)
    fprintf(ff,'\n%s',sujn{k})
    for kk=1:length(roiname)
        fprintf(ff,',%d',volu(k,kk));
    end
end

fclose(ff)
