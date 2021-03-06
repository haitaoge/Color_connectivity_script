function [es pdir totes TE] = get_EPI_readout_time(dcminf,dicom_csv)
%function [es totes] = get_EPI_readout_time(dcminf)
%   es echo spacing (ipat is taken into acount)
%   totes total readouttime in ms

if ischar(dcminf)
    dcminf = spm_dicom_headers(dcminf);
end

if iscell(dcminf)
    dcminf=dcminf{1};
end

TE = dcminf.EchoTime;

bandwidth = dcminf.Private_0019_1028;

nPESamples = str2num(dcminf.Private_0051_100b(1:3));

%ipat = str2num(dcminf.Private_0051_1011(2));

% es = ipat/(bandwidth*nPESamples) * 1E3;

es = 1/(bandwidth*nPESamples) * 1E3;

totes = 1/bandwidth * 1E3;


%%%% PHASE DIRECTION
%cmd =  sprintf('striungs %s |grep sAdjData.sAdjVolume.dInPl',hh.Filename);

pdir='';

if isfield(dcminf,'PhaseEncodingDirection')
    switch dcminf.PhaseEncodingDirection
        case {'COL','COL '}
            pdir='y';
        case {'ROW','ROW '}
            pdir='x';
    end
end



if ~exist(dcminf.Filename,'file')
    if exist('dicom_csv','var')
        if iscell(dicom_csv), dicom_csv = dicom_csv{1};end
        [data res] = readtext(dicom_csv);
        for k=1:size(data,2)
            if strcmp(data{1,k},'phase_angle'),  break;   end
        end
        phase_angle = data{2,k};        

        
    else
        warning('the dicomfile %s does not exist \n CAN NOT FIND THE PHASE DIRECTION',dcminf.Filename);
    end
    
else
    cmd =  sprintf('strings %s |grep dInPlaneRot',dcminf.Filename);
    [a,b] = unix(cmd);
    ii=findstr(b,'=');
    
    if ~isempty(ii)
        if length(ii)>2
            jj = ii(2)-ii(1)-1;
            phase_angle =  b((ii(1)+2):jj);
        else
            
            phase_angle =  b((ii(1)+2):end-1);
        end
        
        phase_angle
    else
        phase_angle=0        
    end
end

if (abs(phase_angle)<pi/4)
    pdir = [pdir '-'];
end


