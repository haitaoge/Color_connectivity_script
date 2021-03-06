function varargout = write_info(output_dir,Filenames,ExamDescription,PatientName,SeriesDescription,unique_serie_index,stop_if_exist,USI)

if ~exist('stop_if_exist'),  stop_if_exist=0;end

I=unique_serie_index;

for k = 1:size(I,1)
    % ecrit dans le repertoire output_dir un fichier texte readme.txt avec tous les 'numserie nomserie'
    ind=find(USI==k);
    if length(ind)>1
        I(k)=ind(floor(length(ind)/2));
    end
    fprintf('%s\t%s\t%s\n',ExamDescription{I(k)},PatientName{I(k)},SeriesDescription{I(k)});
    
    % cree des repertoires exam et series
    exa_dirname = nettoie_dir(ExamDescription{I(k)});
    pat_dirname = nettoie_dir(PatientName{I(k)});
    ser_dirname = nettoie_dir(SeriesDescription{I(k)});
    
    theout_dir = output_dir;
    
    if exist(fullfile(output_dir,exa_dirname,pat_dirname,ser_dirname))
        if ischar(stop_if_exist)
            %      theout_dir = stop_if_exist;
            while exist(fullfile(output_dir,exa_dirname,pat_dirname,ser_dirname))
                for aaa = 1:length(ind)
                    SeriesDescription{ind(aaa)} = [SeriesDescription{ind(aaa)} 'again'];
                end
                ser_dirname = nettoie_dir(SeriesDescription{I(k)});
            end
            
            [s,mess] = mkdir(fullfile(theout_dir,exa_dirname,pat_dirname,ser_dirname));
            
            if s == 0,         error(mess);        end
        else
            if stop_if_exist
                error('Error series directorie %s  exist !!!',fullfile(output_dir,exa_dirname,pat_dirname,ser_dirname))
            else
                warning('Warning series directorie %s  exist !!!',fullfile(output_dir,exa_dirname,pat_dirname,ser_dirname))
            end
        end
        
    else
        [s,mess] = mkdir(fullfile(output_dir,exa_dirname,pat_dirname,ser_dirname));
        if s == 0,         error(mess);        end
    end
    
    
    %ecrit les info du header pour chaque serie
    if isstruct(Filenames{1})
        % this is already the spm_dicom_headers structure
        hhh = Filenames(I(k));
    else
        hhh = spm_dicom_headers(Filenames{I(k)});
    end
    
    hh = hhh{1};
    
    %%%%%%skip strange data (without interest
    hh.ImageType
    if ~isempty(strfind(hh.ImageType,'DERIVED')) || ~isempty(strfind(hh.ImageType,'SECONDARY')) ...
            || ~isempty(strfind(hh.ImageType,'\ADC\')) || ~isempty(strfind(hh.ImageType,'\TENSOR\')) ...
            || ~isempty(strfind(hh.ImageType,'\FA\')) || ~isempty(strfind(hh.ImageType,'\TRACEW\'))...
            || ~isempty(strfind(hh.ImageType,'\OTHER\'))
        continue
    end
    
    switch hh.SOPClassUID
        case '1.2.840.10008.5.1.4.1.1.7'
            %fprintf('skiping FA Color ? convertion %s \n',serie_dir_spm);
            continue
        case '1.3.12.2.1107.5.9.1'
            if strfind(hh.CSAImageHeaderType,'DTI NUM')  %if SPEC NUM 4 it is spectro data
                %fprintf('skiping Tensor ? convertion %s \n',serie_dir_spm);
                continue
            end
    end
    
    %pour les vielle data
    
    if isfield(hh,'SeriesDescription')
        if strfind(upper(hh.SeriesDescription),upper('MPR Range'))
            continue
        end
    end
    
    %%%%%%%%%%%%
    Series_header_name = fullfile(theout_dir,exa_dirname,pat_dirname,'info.txt');
    fids_txt = fopen(Series_header_name,'a+');
    
    %Image_header_name = fullfile(theout_dir,exa_dirname,pat_dirname,[ser_dirname,'_info.txt']);
    diffusion_header_name= fullfile(theout_dir,exa_dirname,pat_dirname,ser_dirname,['diffusion_dir.txt']);
    Series_header_csv = fullfile(theout_dir,exa_dirname,pat_dirname,ser_dirname,'dicom_info.csv');
    Series_header_matlab = fullfile(theout_dir,exa_dirname,pat_dirname,ser_dirname,'dicom_info.mat');
    
    %    if isempty(strfind(output_dir,'dicom_raw'))
    write_dicom_info_to_csv(hhh,Series_header_csv,Series_header_matlab);
    %    end
    
    if k==1
        if isfield(hh,'StudyDate')
            date = datestr(hh.StudyDate);
            [heure,min,sec,ms] = get_time(hh.StudyTime);
            fprintf(fids_txt,'Acquisition Date %s  %dH%d:%d\n',date,heure,min,sec);
        end
    end
    
    if isfield(hh,'SeriesTime')
        [heure,min,sec,ms] = get_time(hh.SeriesTime);
        if isfield(hh,'Private_0051_100a'); TA=hh.Private_0051_100a;else TA='';end
        fprintf(fids_txt,'\n\t%s   : %dH%d:%d  %s\n',char(SeriesDescription(I(k))),heure,min,sec,TA);
    end
    
    fprintf(fids_txt,'info from %s\n',hh.Filename);
    
    if isfield(hh,'CSAImageHeaderType')
        MRtype = hh.CSAImageHeaderType;
    else
        MRtype='OTHER';
    end
    
    %bad quick hack
    if ~isfield(hh,'ImageType')
        hh.ImageType='DERIVED';
    end
    
    if strncmp(hh.ImageType,'DERIVED',7)
        MRtype='OTHER'; %quick hack because derived images do not have physical parameter written in info.txt
    end
    
    % try
    
    if strncmp(MRtype,'IMAGE NUM 4',6)
        write_serie_volume_info(fids_txt,hh)
        
        %        if isfield(hh,'Private_0019_100e') && ~isempty(strfind(hh.SequenceName,'ep_b'))
        if ~isempty(strfind(hh.SequenceName,'ep_b'))
            %diffusion direction or b0 image
            
            write_diffusion_direction(diffusion_header_name,Filenames(USI==k));
        end
        
    elseif strncmp(MRtype,'SPEC NUM 4',6) % spectro
        write_serie_spectro_info(fids_txt,hh)
        
    elseif strncmp(MRtype,'OTHER',5) % derived image
        fprintf(fids_txt,'Type %s (%s)  Sequence ?\n',MRtype,hh.ImageType);
        
        %handel GE PetMR
	if isfield(hh,'ManufacturerModelName')
        if strncmp(hh.ManufacturerModelName,'SIGNA PET/MR')
            keyboard
            write_GE_serie_volume_info(fids_txt,hh);
        end
	end
        
    else
        fprintf('Warning SKIPING header writing series %s of type %s not handle\n',ser_dirname,hh.CSAImageHeaderType);
    end
    
    % catch
    %   warning('Warning PROBLEM in Header writing') ;
    %   a=lasterror;
    %   disp(a.message);
    % end
    
    fclose(fids_txt);
    
end


varargout{1} = SeriesDescription;


function [h,m,s,ms] = get_time(t)

h = floor(t/3600);
mm = t/3600 -h;
m = floor(mm*60);
ss = mm*60-m;
s = floor(ss*60);
ms = floor((ss*60-s)*1000);


function arg
for k=1:80 ;
    name{k} = h.CSAImageHeaderInfo(k).name;
    if length( h.CSAImageHeaderInfo(k).item)>1
        value{k} = h.CSAImageHeaderInfo(k).item(1).val;
    end
end

for k=1:55 ;
    names{k} = h.CSASeriesHeaderInfo(k).name;
    if length( h.CSASeriesHeaderInfo(k).item)>1
        values{k} = h.CSASeriesHeaderInfo(k).item(1).val;
    end
end


for k=1:80 ;
    if strcmp(name{k},'DiffusionGradientDirection')
        break
    end
end
k
