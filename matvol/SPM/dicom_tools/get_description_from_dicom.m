function [ExamDescription,PatientName,SeriesDescription,unique_serie_index,USI,hdr_dic] = get_description_from_dicom(Filenames)

global GUIOK
if isempty(GUIOK), GUIOK=0; end

SeriesDescription = []; ExamDescription = []; PatientName=[];
UniqueSeriesDescription=[];UniqueExamDescription=[];
%ExamNumber = [];    SeriesNumber = [];
ExamUID =[];

if (GUIOK)    h = waitbar(0,'Getting information from DICOM files...'); end
has_corrupt=0;ind_corrupt=[];

for i=1:length(Filenames)
    
    hh = spm_dicom_headers(Filenames{i});
    if isempty(hh)
        fprintf('CORRUPT DICOM FILE : %s \n ',Filenames{i});
        has_corrupt=1;
        ind_corrupt(end+1) = i;
        continue
    end
    hdr_dic{i} = hh{1};
    
    if ~isempty(hh)
        hdr = hh{1};

        if strfind(hdr.Modality,'PET RAW')
            has_corrupt=1; 
	    ind_corrupt(end+1) = i;
            continue
        end
        
        if hdr.Modality == 'MR' |  hdr.Modality == 'OT' |  hdr.Modality == 'SR'  |  hdr.Modality == 'PT'
            
            if isfield(hdr,'StudyDescription')
                E_description = [hdr.StudyDescription];
            else
                %if strfind(hdr.PatientName,'Service Patient')
                %    E_description = 'ServicePatient';
                if isfield(hdr,'PatientName')
                    E_description = hdr.PatientName;
                elseif isfield(hdr,'PatientsName')
                    E_description = hdr.PatientsName;
                elseif isfield(hdr,'ProtocolName')
                    E_description = [hdr.ProtocolName];
                else
                    E_description = datestr(hdr.StudyDate);
                end
            end
            
            Snum = sprintf('S%.2d',hdr.SeriesNumber);
            if isfield(hdr,'SeriesDescription')
                S_description = [Snum, '-',hdr.SeriesDescription];
            else
                if isfield(hdr,'ProtocolName')
                    S_description = [Snum, '-',hdr.ProtocolName];
                else
                    S_description = [Snum];
                end
            end
            
            %chagement le 11 2015
            if strfind(hdr.ImageType,'\P\')
                S_description = [S_description '_phase'];
            end
            
            %Attetion changement le 15/11/2013 en fait StudyDate c'est la creation de la study mais Acquisition date c'est bien la date d'acquisition
            %P_description = [datestr(hdr.StudyDate,29), '_', hdr.PatientsName ];            
%             if ~isfield(hdr,'AcquisitionDate') %for spectro data
%                 thedate = hdr.StudyDate;
%             else
%                 if hdr.StudyDate>hdr.AcquisitionDate %I do not know why this happen for tensor series
%                     thedate = hdr.StudyDate;
%                 else
%                     thedate = hdr.AcquisitionDate;
%                 end
%             end
            %changement le 12 2015 
            if ~isfield(hdr,'SeriesDate') %for spectro data
                thedate = hdr.StudyDate;
            else
                if ~isfield(hdr,'StudyDate')
                    thedate = hdr.SeriesDate;
                else
                    if hdr.StudyDate>hdr.SeriesDate %I do not know why this happen for tensor series
                        thedate = hdr.StudyDate;
                    else
                        thedate = hdr.SeriesDate;
                    end
                end
            end
            
            
            if ~isfield(hdr,'PatientsName')
                P_description = [datestr(thedate,29), '_', hdr.PatientName ];
            else
                P_description = [datestr(thedate,29), '_', hdr.PatientsName ];
            end
            
            
            if isfield(hdr,'StudyID')
                if str2num(hdr.StudyID) > 1
                    P_description = [ P_description ,'_E',num2str(str2num(hdr.StudyID))];
                end
            end
            
            if isfield(hdr,'InstanceNumber')
                acnum(i) = hdr.InstanceNumber;
                %	if isfield(hdr,'EchoNumbers')
                %	  echonum(i) = hdr.EchoNumbers;
                %	end
            end
            
            SeriesDescription = [SeriesDescription;{S_description}];
            ExamDescription = [ExamDescription;{E_description}];
            PatientName = [PatientName;{P_description}];
            
            UniqueSeriesDescription = [UniqueSeriesDescription;{[E_description '_' P_description '_' S_description]}];
            UniqueExamDescription = [UniqueExamDescription;{[E_description '_' P_description ]}];
            
            %    ExamNumber = [ExamNumber;str2num(hdr.StudyID)];
            %    SeriesNumber = [SeriesNumber;hdr.SeriesNumber];
            ExamUID = [ExamUID; {hdr.StudyInstanceUID}];
        else
            keyboard
        end
        
        if (GUIOK)        waitbar(i/length(Filenames),h);end
    end
    
end

if (GUIOK)    close(h);end


[S,I,USI] = unique(UniqueSeriesDescription);
[E,J] = unique(ExamUID);
[ed,id]=unique(UniqueExamDescription);


%si les nom ne sont pas unique (contrairement aux id)
if size(ed,1)~=size(E,1)
    fprintf('%s\n','AILLL changing exam description, because of non unique exam number');
    for k = 1:size(ExamDescription,1)
        kk=1;
        while isempty(strfind(ExamUID{k},E{kk})) %any(ExamUID{k}~=E{kk})
            kk=kk+1;
        end
        PatientName{k} = [PatientName{k} '_' num2str(kk)];
        UniqueSeriesDescription{k} = [ExamDescription{k} PatientName{k} SeriesDescription{k}];
    end
    [S,I,USI] = unique(UniqueSeriesDescription);
end

unique_serie_index=I;

for k=1:length(I)
    aa = acnum(USI==k);
    if length(aa)>1
        maxinstance = max(aa);
        num_file = length(aa);
        
        %    if exist('echonum')
        %      ee=echonum(USI==k);maxinstance = maxinstance * max(ee);
        %    end
        
        ser_d=SeriesDescription(USI==k);
        
        if mod(length(aa),maxinstance)
            
            if findstr(ser_d{1},'t-Map')
                %just skip it
            else
                
                
                msg=sprintf('Arg for the serie \n%s\n there is only %d files but the max instance number is %d\n',S{k},length(aa),maxinstance);
                
                setpref('Internet','SMTP_Server','mailhost.chups.jussieu.fr');
                setpref('Internet','E_mail','thebest@cenir');
                try
                    sendmail('valabregue@chups.jussieu.fr','dicom transfer error',msg);
                catch
                end
                
                fprintf(msg);
                
            end
            
        end
    end
end

if has_corrupt
    %keyboard
    hdr_dic(ind_corrupt)='';
end

