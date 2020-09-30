% For writing or rewriting EDF files.
% Originally had been part of CLASS_converter.m, and separated out to this 
% stand alone class with some additional methods on 12/18/2019.

% @author Hyatt Moore IV and Adam Rhine (see comments)

classdef EDFWriter
    
    properties(Constant)
       EDFHDRSignalFields = {
           'label'
           'transducer'
           'physical_dimension'
           'physical_minimum'
           'physical_maximum'
           'digital_minimum'
           'digital_maximum'
           'prefiltering'
           'number_samples_in_each_data_record'
           'reserved_for_signals'
           }; 
    end
    methods(Static)
        
        %> @brief Rewrite an EDF.
        %> @param fullSrcFilename
        %> @param fullDestFilename
        %> @param mergeIndices
        %> @param HDREntriesToMerge
        %> @retval success Is a true or false flag.
        function success = rewriteEDF(fullSrcFilename,fullDestFilename,mergeIndices,HDREntriesToMerge)
            try
                [HDR, channelData] = loadEDF(fullSrcFilename);
                numMerges = size(mergeIndices,1);
                mergeData = cell(numMerges,1);
                for n=1:numMerges
                    sig_1 = channelData{mergeIndices(n,1)};
                    sig_2 = channelData{mergeIndices(n,2)};
                    % Can happen if sample rates are different.
                    if numel(sig_1) == numel(sig_2)
                        mergeData{n} = sig_1-sig_2;
                    else
                        fprintf(1,'[WARNING] Will not adjust dereference signals of different size (%s)\n',fullSrcFilename);
                        mergeData{n} = sig_1;
                    end
                end
                
                % create section data cell and header of remaining/non-merged EDF channels
                nonmergeHDR = EDFWriter.purgeEDFHeader(HDR,unique(mergeIndices(:)));
                channelData(mergeIndices(:)) = []; % this is the non merged data
                
                % merge everything together
                mergedData = [channelData; mergeData];
                mergedHDR = EDFWriter.mergeEDFHeader(nonmergeHDR,HDREntriesToMerge);
                
                % prep it for EDF format
                for c=1:numel(mergedData)
                    mergedData{c} = EDFWriter.double2EDFReadyData(mergedData{c},mergedHDR,c);
                end
                
                % should we filter first?
                %     fir_bp.params.start_freq_hz = 1;
                %     fir_bp.params.stop_freq_hz = 49;
                %
                %     fir_bp.params.sample_rate = HDR.samplerate(channels.legs(1));
                %     fir_bp.params.order = fir_bp.params.sample_rate;
                %     data.legs = +filter.fir_bp(data.legs,fir_bp.params);
                
                mergedHDR.num_signals = numel(mergedData);
                
                EDFWriter.writeEDF(fullDestFilename,mergedHDR,mergedData);
                % writeEDF throws an error on failure
                success = true;
                
            catch me
                showME(me);
                success = false;
            end
        end
        
        %> @brief extract HDR entries from indices at extractIndices
        %> extractIndices is a 1-based vector of indices to purge from HDR
        %> @param HDR Header from an EDF file
        %> @param extractIndices
        %> @retval extractedHDR EDF header containting values found at
        %> extractInidces.
        function extractedHDR = extractEDFHeader(HDR, extractIndices)
            extractedHDR = HDR;
            for n=1:numel(EDFWriter.EDFHDRSignalFields)
                curFieldname = EDFWriter.EDFHDRSignalFields{n};
                extractedHDR.(curFieldname) = HDR.(curFieldname)(extractIndices);
            end
            extractedHDR.num_signals = numel(extractedHDR.label);
        end       
        
        %> @brief Remove HDR entries at indices purgeIndices
        %> @param HDR The header found in an .EDF file
        %> @param purgeIndices is a 1-based vector of indices to purge from HDR
        %> @retval purgedHDR The HDR with values removed at purgeIndices.
        function purgedHDR = purgeEDFHeader(HDR, purgeIndices)
            purgedHDR = HDR;
            for n=1:numel(EDFWriter.EDFHDRSignalFields)
                curFieldname = EDFWriter.EDFHDRSignalFields{n};
                purgedHDR.(curFieldname)(purgeIndices) = [];
            end
        end
        
        %> @brief Merge EDF header information.
        %> @param HDR
        %> @param HDRentriesToMerge
        %> @retval mergedHDR
        function mergedHDR = mergeEDFHeader(HDR,HDRentriesToMerge)
            % combine HDR and mergeHDRentries here
            mergedHDR = HDR;
            for n=1:numel(EDFWriter.EDFHDRSignalFields)
                curFieldname = EDFWriter.EDFHDRSignalFields{n};
                if(iscell(curFieldname))
                    mergedHDR.(curFieldname) = [HDR.(curFieldname){:};HDRentriesToMerge.(curFieldname){:}];
                else
                    mergedHDR.(curFieldname) = [HDR.(curFieldname)(:);HDRentriesToMerge.(curFieldname)(:)];
                end
            end
        end
        
        function [isValid, corrected_HDR] = checkEDFHeader(edf_filename)
            
            if ~exist(edf_filename, 'file')
                isValid = false;
                corrected_HDR = [];
            else
                try                    
                    [HDR, signals] = loadEDF(edf_filename);
                    isValid = true;
                    corrected_HDR = HDR;
                    isCorrectable = true;
                    total_samples_expected = HDR.number_samples_in_each_data_record.*HDR.number_of_data_records;
                    if iscell(signals)
                        num_samples_found = cellfun(@numel,signals);
                    else
                        num_samples_found = size(signals,2);
                    end
                    
                    corrected_HDR.T0 = datevec(datenum(HDR.T0));
                    if ~isequal(corrected_HDR.T0, HDR.T0)
                        fprintf('Invalid start time stamp found in %s.  Fixing.\n', edf_filename);
                        isValid = false;
                        corrected_HDR.startdate = datestr(corrected_HDR.T0, 'dd.mm.YY');
                        corrected_HDR.starttime = datestr(corrected_HDR.T0, 'HH.MM.SS');
                    end
                    
                    if ~isequal(total_samples_expected, num_samples_found)
                        isValid = false;
                        if all(total_samples_expected > num_samples_found)
                            num_data_records = num_samples_found./HDR.number_samples_in_each_data_record;
                            fprintf(1,'Total samples expected from the header exceeds number of samples found in the file (%s).  ', edf_filename);

                            if all(num_data_records==num_data_records(1))
                                corrected_HDR.number_of_data_records = num_data_records(1);
                                fprintf(1, 'Reducing ''number_of_data_records'' field in EDF header to %d.\n', corrected_HDR.number_of_data_records);
                            else
                                fprintf(1, 'Could not find a stable value for the ''number_of_data_records'' field in the EDF header to change to.  FAIL.\n');                                
                            end
                        elseif all(total_samples_expected < num_samples_found)
                            isCorrectable = false;
                            fprintf(1,'Total samples expected from the header is less than the number of samples found in the file (%s).  FAIL.\n', edf_filename);
                        else
                            isCorrectable = false;
                            fprintf(1,'Total samples expected from the header is sometimes more and sometimes less than the number of samples found in the file (%s).  FAIL.\n', edf_filename);
                        end                            
                    end
                    
                    invalid_dim_indices = cellfun(@(c) ~isempty(c) && any(c>127),corrected_HDR.physical_dimension);
                    if any(invalid_dim_indices)
                        isValid = false;
                        % Try
                        % char(corrected_HDR.physical_dimension(invalid_dim_indices)/2)
                        % to bit shift and get something like 'Pc' from char('¡Æ'/2)
                        fprintf(1,'Invalid physical dimension entry (not 7-bit ASCII) found in header of file (%s).  Replacing with ''?''.\n', edf_filename);
                        corrected_HDR.physical_dimension(invalid_dim_indices) = {'?'};                        
                    end                    
                    if ~isValid && ~isCorrectable
                        corrected_HDR = [];
                    end
                catch me
                    showME(me);
                    isValid = false;
                    corrected_HDR = [];
                end
            end
        end 
        
        %> @brief Rewrite an EDF header
        %> @param edf_filename
        %> @param label_indices = vector of indices (1-based) of the label to be replaced in
        %> the EDF header
        %> @param new_labels = cell of label names
        %> @note: Author: Hyatt Moore IV
        %> 10.18.2012
        function success = rewriteEDFHeader(edf_filename, label_indices,new_labels)
            success = false;
            if(exist(edf_filename,'file'))
                
                fid = fopen(edf_filename,'r+');
                
                fseek(fid,252,'bof');
                number_of_channels = str2double(fread(fid,4,'*char')');
                label_offset = 256; % ftell(fid);
                out_of_range_ind = label_indices<1 | label_indices>number_of_channels;
                label_indices(out_of_range_ind) = [];
                new_labels(out_of_range_ind) = [];
                num_labels = numel(new_labels);
                label_size = 16; % 16 bytes
                
                for k=1:num_labels
                    numChars = min(numel(new_labels{k}),label_size);
                    new_label = repmat(' ',1,label_size);
                    new_label(1:numChars) = new_labels{k}(1:numChars);
                    fseek(fid,label_offset+(label_indices(k)-1)*label_size,'bof');
                    fwrite(fid,new_label,'*char');
                end
                fclose(fid);
                success = true;
            end
        end
        
        function success = updateEDFHeader(edf_filename, HDR)
            success = false;
            if(exist(edf_filename,'file'))                
                fid = fopen(edf_filename,'r+');
                EDFWriter.fwriteHDR(fid, HDR);
                fclose(fid);
                success=true;
            end
        end            
        
        function hdr = deidentifyHDR(hdr)
            hdr.patient(:) = ' ';
            hdr.local(:) = ' ';
            hdr.starttime = '00.00.00';
            hdr.startdate = '01.01.01';
        end
        
        
        function success = writeLiteEDF(fullSrcFilename, fullDestFilename, channelIndicesOrCell, resampleRate)
            try                
                addNoise = false; % uh oh!
                if(addNoise)
                    rng('shuffle');
                end
                HDR = loadEDF(fullSrcFilename);                
                if(iscell(channelIndicesOrCell))
                    [~,channelIndices] = intersect(HDR.label,channelIndicesOrCell);
                else
                    channelIndices = channelIndicesOrCell;
                end
                
                [HDR, channelData] = loadEDF(fullSrcFilename, channelIndices(:));
                
                liteHDR = EDFWriter.extractEDFHeader(HDR,channelIndices);
                liteHDR = EDFWriter.deidentifyHDR(liteHDR);
                
                if(nargin<4 || isempty(resampleRate) || resampleRate == 0)
                    resampleRate = [];
                else
                    % Transform to 1 second records.
                    liteHDR.number_of_data_records = liteHDR.number_of_data_records*liteHDR.duration_of_data_record_in_seconds;
                    liteHDR.duration_of_data_record_in_seconds = 1;
                    liteHDR.duration_sec = liteHDR.number_of_data_records;
                end
                
                if(~iscell(channelData) && ~isempty(channelData))
                    channelData = {channelData};
                end
                for c=1:numel(channelData)
                    if(~isempty(resampleRate))
                        % get the sample rate from the header's original
                        % channel location of the first merge index.  If we
                        % have different sampling rates for the merge pair
                        % we will have errored out already.
                        srcSamplerate = HDR.samplerate(channelIndices(c));
                        [N,D] = rat(resampleRate/srcSamplerate);     % reSamplerate = srcSamplerate*N/D
                        
                        if(N~=D)
                            if(numel(channelData{c})>0)
                                channelData{c} = resample(channelData{c},N,D); %resample to get the desired sample rate
                                % liteHDR.number_samples_in_each_data_record(c) = liteHDR.number_samples_in_each_data_record(c) * N/D;  % should be reSamplerate
                            end
                        end
                        liteHDR.number_samples_in_each_data_record(c) = resampleRate;  % data records are 1 second.  
                    end
                    
                    %if(addNoise)
                    %    channelData{c} = channelData{c}+randn(size(channelData{c}));
                    %end
                    
                    channelData{c} = EDFWriter.double2EDFReadyData(channelData{c},liteHDR,c); % we want the lite header because it goes from 1:numel(channelData) and will match up correctly with c
                    
                end
                EDFWriter.writeEDF(fullDestFilename,liteHDR,channelData);
                success = true;
            catch me
                showME(me);
                success = false;
            end
        end
        
        %> @brief Rewrite a culled EDF.  Only transfer over the merged
        %> information, and nothing else (i.e. cull unspecified data).
        %> @param fullSrcFilename Original EDF filename
        %> @param fullDestFilename Exported, culled EDF filename
        %> @param mergeIndices
        %> @param HDREntriesToMerge
        %> @retval success Is a true or false flag.
        function success = rewriteCulledEDF(fullSrcFilename,fullDestFilename,mergeIndices,mergeHDR, reSamplerate)
            try
                
                % Channel data is returned as a (2*N)x1 cell where N is the
                % number of merge pairs; i.e. size(mergeIndices,1);  The
                % loadEDF function returns the mergeIndices channels into
                % channelData, where channelData pairs are separated by N
                % rows within the cell.
                
                if(nargin<5 || reSamplerate<=0)
                    reSamplerate = [];
                else
                    % Set the number of data records to be equal to the
                    % total number of seconds.  This will make things
                    % easier when resampling later.
                    mergeHDR.number_of_data_records = mergeHDR.number_of_data_records*mergeHDR.duration_of_data_record_in_seconds;
                    mergeHDR.duration_of_data_record_in_seconds = 1;
                    mergeHDR.duration_sec = mergeHDR.number_of_data_records;
                end
                
                [HDR, channelData] = loadEDF(fullSrcFilename, mergeIndices(:));
                numMerges = size(mergeIndices,1);
                mergedData = cell(numMerges,1);
                for n=1:numMerges
                    mergedData{n} = channelData{n}-channelData{n+numMerges};
                    if(~isempty(reSamplerate))
                        % get the sample rate from the header's original
                        % channel location of the first merge index.  If we
                        % have different sampling rates for the merge pair
                        % we will have errored out already.
                        srcSamplerate = HDR.samplerate(mergeIndices(n));
                        [N,D] = rat(reSamplerate/srcSamplerate);     % reSamplerate = srcSamplerate*N/D
                        
                        if(N~=D)
                            if(numel(mergedData{n})>0)
                                mergedData{n} = resample(mergedData{n},N,D); %resample to get the desired sample rate
                                mergeHDR.number_samples_in_each_data_record(n) = mergeHDR.number_samples_in_each_data_record(n) * N/D;  % should be reSamplerate
                            end
                        end
                    end
                    mergedData{n} = EDFWriter.double2EDFReadyData(mergedData{n},mergeHDR,n);
                end
                
                mergeHDR.num_signals = numel(mergedData);
                EDFWriter.writeEDF(fullDestFilename,mergeHDR,mergedData);
                success = true;
                
            catch me
                showME(me);
                success = false;
            end
        end
        
        %> @brief helper function for something, but it has been a while
        %  Hyatt Moore, IV
        %  < June, 2013
        %> @param signal is a vector of type double
        %> @param HDR is the HDR information only for the signal passed
        %> @param k is the index of signal in the HDR (.EDF)
        %> @retval edfData
        function edfData = double2EDFReadyData(signal,HDR,k)
            edfData = int16((signal-HDR.physical_minimum(k))*(HDR.digital_maximum(k)-HDR.digital_minimum(k))/(HDR.physical_maximum(k)-HDR.physical_minimum(k))+HDR.digital_minimum(k));
        end
        
        
        %> @brief % Writes EDF files (not EDF+ format); if no HDR is specified then
        % a "blank" HDR is used. If no signals are specified, 2 signals of
        % repeating matrices of 5000 and 10000 are used.
        %> @param filename
        %> @param HDR
        %> @param signals
        %> @retval HDR
        %> @retval signals
        %> @note written by Adam Rhine  (June, 2011)
        %> @note updated by Hyatt Moore (January, 2014; March, 2020)
        function [HDR, signals] = writeEDF(filename, HDR, signals)
            if(nargin==0)
                disp 'No input filename given; aborting';
                return;
            end
            
            if (nargin==1)  % If no HDR specified, blank HDR used instead
                HDR.ver = 0;
                HDR.patient = 'UNKNOWN';
                HDR.local = 'UNKNOWN';
                HDR.startdate = '01.01.11';
                HDR.starttime = '00.00.00';
                HDR.HDR_size_in_bytes = 768;
                HDR.number_of_data_records = 18522;
                HDR.duration_of_data_record_in_seconds = 1;
                HDR.num_signals = 1;
                HDR.label = {'Blank1'};
                HDR.transducer = {'unknown'};
                HDR.physical_dimension = {'uV'};
                HDR.physical_minimum = -250;
                HDR.physical_maximum = 250;
                HDR.digital_minimum = -2048;
                HDR.digital_maximum = 2047;
                HDR.prefiltering = {'BP: 0.1HZ -100HZ'};
                HDR.number_samples_in_each_data_record = 100;
            end
            
            if(nargin<3)    % If no signals specified, fills with num_signals worth of repeating signals (5000 for first signal, 10000 for second, etc.)
                disp(HDR.num_signals);
                signals = cell(HDR.num_signals,1);
                for k=1:HDR.num_signals
                    signals{k}=repmat(5000*k,1852200,1);
                end
            end
            if(nargin>=3)
                if(HDR.num_signals == 0)
                    if(iscell(signals))
                        HDR.num_signals = numel(signals);
                    else
                        HDR.num_signals = size(signals,1);  % signals are (should be) stored as row entries
                    end
                end
                if(nargin>3)
                    disp('Too many input arguments in loadEDF.  Extra input arguments are ignored');
                end
            end
            
            fid = fopen(filename,'w');
            HDR = EDFWriter.fwriteHDR(fid, HDR);  %size in bytes field is updated in HDR struct after fwriteHDR completes.           
            ns = HDR.num_signals;
            % just do the whole thing slowly - at least we know it will work            
            try
                for rec=1:HDR.number_of_data_records
                    for k=1:ns
                        samples_in_record = HDR.number_samples_in_each_data_record(k);
                        
                        range = (rec-1)*samples_in_record+1:(rec)*samples_in_record;
                        if(iscell(signals))
                            currentsignal = int16(signals{k}(range));
                        else
                            currentsignal = int16(signals(k,range));
                        end
                        fwrite(fid,currentsignal,'int16');
                    end
                end
                fclose(fid);
                
            catch me
                showME(me);
                fclose(fid);
                rethrow(me);
            end            
        end
        
        % HDR is struct, fid is file handle of EDF being written to,
        % which better be at 0!
        function HDR = fwriteHDR(fid, HDR)
            % 'output' becomes the header
            output = EDFWriter.resize(num2str(HDR.ver),8);
            output = [output EDFWriter.resize(HDR.patient,80)];
            output = [output EDFWriter.resize(HDR.local,80)];
            output = [output EDFWriter.resize(HDR.startdate,8)];
            output = [output EDFWriter.resize(HDR.starttime,8)];
            
            % location is currently 160+24+1 ("1-based") = 185
            output = [output EDFWriter.resize(num2str(HDR.HDR_size_in_bytes),8)];
            output = [output repmat(' ',1,44)]; % HDR.reserved
            output = [output EDFWriter.resize(num2str(HDR.number_of_data_records),8)];
            output = [output EDFWriter.resize(num2str(HDR.duration_of_data_record_in_seconds),8)];
            output = [output EDFWriter.resize(num2str(HDR.num_signals),4)];
            output = [output EDFWriter.rep_sig(HDR.label,16)];
            output = [output EDFWriter.rep_sig(HDR.transducer,80)];
            output = [output EDFWriter.rep_sig(HDR.physical_dimension,8)];
            output = [output EDFWriter.rep_sig_num(HDR.physical_minimum,8,'%1.1f')];
            output = [output EDFWriter.rep_sig_num(HDR.physical_maximum,8,'%1.1f')];
            output = [output EDFWriter.rep_sig_num(HDR.digital_minimum,8)];
            output = [output EDFWriter.rep_sig_num(HDR.digital_maximum,8)];
            output = [output EDFWriter.rep_sig(HDR.prefiltering,80)];
            output = [output EDFWriter.rep_sig_num(HDR.number_samples_in_each_data_record,8)];
            
            ns = HDR.num_signals;
            
            for k=1:ns
                output = [output repmat(' ',1,32)]; % reserved...
            end
            
            HDR.HDR_size_in_bytes = numel(output);
            output(185:192) = EDFWriter.resize(num2str(HDR.HDR_size_in_bytes),8);
            
            precision = 'uint8';
            fwrite(fid,output,precision); % Header is written to the file
        end
                
        %> @brief Modifies a string ('input') to be as long as 'length', with blanks filling
        %> in the missing chars
        %> @param input
        %> @param length
        %> @retval resized_string
        % written by Adam Rhine  (June, 2011)        
        function [resized_string] = resize(input,length)
            resized_string = repmat(' ',1,length);
            for k=1:numel(input)
                resized_string(k)=input(k);
            end
        end        
        
        %> @brief Same as resize(), but does so for all elements in a cell array
        %> @param input
        %> @param length
        %> @retval multi_string
        % written by Adam Rhine  (June, 2011)
        function [multi_string] = rep_sig(input,length)
            multi_string = '';
            for k=1:numel(input)
                multi_string = [multi_string EDFWriter.resize(input{k},length)];
            end
        end
        
        %> @brief Same as rep_sig(), but does so for all elements in a matrix of doubles
        %> @param input
        %> @param length
        %> @param prec ('%1.0f' is the default precision)
        %> @retval multi_string
        % written by Adam Rhine  (June, 2011)
        function [multi_string] = rep_sig_num(input,length,prec)
            
            if (nargin<3)
                prec = '%1.0f';
            end
            
            multi_string = '';
            
            for k=1:numel(input)
                multi_string = [multi_string EDFWriter.resize(num2str(input(k),prec),length)];
            end
        end        
    end    
end