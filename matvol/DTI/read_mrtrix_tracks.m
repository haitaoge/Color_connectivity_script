function tracks = read_mrtrix_tracks (filename)

% function: tracks = read_mrtrix_tracks (filename)
%
% returns a structure containing the header information and data for the MRtrix 
% format image 'filename' (i.e. files with the extension '.mif' or '.mih').

[tracks file] = read_mrtrix_tracks_hdr(filename);

[ file, offset ] = strtok(file);
if ~strcmp(file,'.')
  disp ('unexpected file entry (should be set to current ''.'') - aborting')
  return;
end

if isempty(offset)
  disp ('no offset specified - aborting')
  return;
end
offset = str2num(char(offset));

datatype = lower(tracks.datatype);
byteorder = datatype(end-1:end);

if strcmp(byteorder, 'le')
  f = fopen (filename, 'r', 'l');
  datatype = datatype(1:end-2);
elseif strcmp(byteorder, 'be')
  f = fopen (filename, 'r', 'b');
  datatype = datatype(1:end-2);
else
  disp ('unexpected data type - aborting')
  return;
end

if (f<1) 
  disp (['error opening ' filename ]);
  return
end

fseek (f, offset, -1);
data = fread(f, inf, datatype);
fclose (f);

N = floor(prod(size(data))/3);
data = reshape (data, 3, N)';
k = find (~isfinite(data(:,1)));

tracks.data = {};
pk = 1;
for n = 1:(prod(size(k))-1)
  tracks.data{end+1} = data(pk:(k(n)-1),:);
  pk = k(n)+1;
end
  

