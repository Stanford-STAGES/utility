% @brief Subclass of CLASS_converter.  Contains montage configurations that
% are helpful for normalizing sleep cohorts for use with the
% stanford-stages manuscript's dataset.

% @author Hyatt Moore, IV
classdef CLASS_edf_converter < CLASS_converter
    
    methods
        function obj = CLASS_edf_converter(varargin)
            obj@CLASS_converter(varargin{:});            
        end
     
    
        %implementing conversion function
        function convert2wsc(obj)
            %export the .EDF files at 100 Hz
            exportSamplerate = 100;
            obj.exportFlatEDFPath([], exportSamplerate);
            % obj.exportFlatEDFPath();
        end        
    end
    
    methods(Static)
        
        function [dualchannel, singlechannel, unhandled] = getMontageConfigurations()            
            unhandled ={
                {'Cannula'}
                {'TIDAL VOLUME'}
                {'USER1'}
                {'light'}
                {'EKG Not used'}
                {'EKG-QRS'}
                {'A1'}
                {'A1+A2-A2'}
                {'A1/A2'}
                {'A1A2'}
                {'A2'}
                {'F3'}
                {'F4'}
                {'O1'}
                {'O2'}
                {'C3'}
                {'C4'}
                {'ROC'}
                {'LOC'}
                {'Fp1'}
                {'Fp1/Fp2'}
                {'Fp2'}
                {'Fz'}
                {'P3'}
                {'P4'}
                {'PRESSURE'}
                {'RIC Not used'}
                {'CPAP'}
                {'IPAP'}
                {'EPAP'}
                {'NAF'}
                {'Nasal-Oral'}
                {'PAP Tidal Volume'}
                {'T3-O1'}
                {'T3/T5'}
                {'T4-O2'}
                {'C3-O1'}
                {'C3-AVG'}
                };
            
            %quad channel configuration?
            %             {'L-LEG1'}
            %             {'L-LEG2'}
            %             {'R-LEG1'}
            %             {'R-LEG2'}
            %             {'L-LEG REF'}
            %             {'L-TIB REF'}
            %             {'R-TIB REF'}
            %             {'R-LEG REF'}
            
            dualchannel = {
                {'C3','A2','C3-A2'}
                {'C3','M2','C3-M2'}
                {'C4','A1','C4-A1'}
                {'C4','M1','C4-M1'}                
                {'C4','M2','C4-M2'}
                {'O1','A2','O1-A2'}
                {'O1','M2','O1-M2'}
                {'O2','A1','O2-A1'}
                {'O2','M1','O2-M1'}
                {'Fz','A1','Fz-A1'}
                {'Fz','A2','Fz-A2'}
                {'Fp1','A2','F1-A2'}
                {'Fp2','C4','F2-C4'}
                {'Fp2','T4','F2-T4'}
                {'EOG1','A2','LEOG-A2'}
                {'EOG2','A1','REOG-A1'}
                {'EOGG','EEG A2','LEOG-A2'} %EOGG - G for la gauche (left in french)
                {'EOGD','EEG A1','REOG-A1'} %EOGD - D for droit/e (right in french)                
                {'LOC','A2','LOC-A2'}
                {'LOC','M2','LOC-M2'}
                {'ROC','A1','ROC-A1'}
                {'ROC','M1','ROC-M1'}
                {'EKG-R','EKG-L','EKG'}
                {'EKG1','EKG2', 'EKG'}
                {'Arms-1','Arms-2','Arms'}
                {'EMG1','EMG2','Chin1-Chin2'}
                {'EMG2','EMG3','Chin2-Chin3'}
                {'EMG1','EMG3','Chin1-Chin3'}
                {'Chin1','Chin2','Chin1-Chin2'}
                {'Chin2','Chin3','Chin2-Chin3'}
                {'Chin1-Chin Z','Chin2-Chin Z','Chin EMG'}
                {'LAT','RAT','LAT-RAT'}
                {'ECG','ECG REF', 'EKG'}
                {'RIC-1','RIC-2','RIC'}
                {'Snore2','Snore-REF','Snore'}
                };          
            
            singlechannel = {                
                {'BODY', 'Body', 'Body Position','POSITION','POS','PositionSen','Pos Sensor','Position'}; 
                {'ABD','ABDO','Abdo','ABDM','ABDOMEN','ABDOMINAL','ADB','Abd','Effort ABD','Abdomen'};                
                {'Arms, Both','ARMS', 'Arm EMG','Arms'};                
                {'THOR', 'THORACIC','THORAX','Thoracic','Thorax','CHEST','Effort Tho','Chest'};                
                {'RIC',  'Intercostal','RIC'}
                {'CHIN1','EMG Ment1','EMG1','Chin1'};
                {'CHIN2','EMG Ment2','EMG2','Chin2'};
                {'MASG','M1'};
                {'MASD','M2'};
                {'CHIN3','EMG Ment3','EMG3','Chin3 Ref','Chin3'};
                {'EMG', 'EMG_SM','EMG-Chin','Chin','EMG Chin','CHIN','CHIN EMG','CHIN1','Chin 1-Chin 2','Chin1-Chin2','Chin1-Chin3','Chin3-Chin2', 'EMG EMG Chin', 'EMG Chin','Subm', 'Chin EMG'};  % EMG_SM from italian cohort   %Subm is from the korean cohort
                {'Leg-L','LEG/L','Leg/L','Lleg1-Lleg2','L-Tib','Tib-L','LAT','LEGS-L','LEMG', 'LEFT TIBIALIS','LEG, Left','LTIB','Left Tib','Legs, Left','EMG Tib-L','EMG Tib. L','EMG_TIB L','LAT'};
                {'Leg-R','R-Tib','LEG/R','Leg/R','Tib-R','LEG, Right','RLEG1-RLEG2','Rleg1-Rleg2','LEG-R','Legs, Right','RTIB', 'Right Tib','RAT','RIGHT TIBIALIS','EMG Tib-R','EMG Tib. R','EMG_TIB R','RAT'};
                {'EMG-Legs','LAT RAT', 'Legs, Both','LLEG1-RLEG1','LLEG1-RLEG2','LLEG2-RLEG1','LLEG2-RLEG2','L/RAT','LAT-RAT'};
                {'EKG1-EKG2','LLEG1-EKG2','ECG','EKG'};
                {'EEG-Central-C3','EEG C3','C3'};
                {'EEG-Central-C4','EEG C4','C4'};
                {'EEG-Occ-O1','EEG O1','O1'};
                {'EEG-Occ-O2','EEG O2','O2'};
                {'EEG F3','F3'};
                {'EEG F4','F4'};
                {'EEG T3','T3'};
                {'EEG T4','T4'};
                {'EEG Fp1','Fp1'};
                {'EEG Fp2','Fp2'};
                {'EEG A1','A1'};
                {'EEG A2','A2'};
                {'EEG M1','M1'};
                {'EEG M2','M2'};
                {'O1 - (M1+M2)','O1 - M1M2','O1, A1-A2','O1-(A1-A2)','O1-(M1+M2)','O1-A1+A2','O1A2','01/A2','01-M1,M2','O1-A2','O1-AVG','O1-M2','EEG O1-A2', 'O1/A2', 'O1_A2','O1-x'};
                {'O2 - (M1+M2)','O2 - M1M2','O2, A1-A2','O2-(A1-A2)','O2-(M1+M2)','O2-A1+A2','02/A1','02,M1,M2','02-M1,M2','O2-A1','O2-AVG','O2-M1','EEG O2-A1','O2-x'};
                {'C3 - (M1+M2)', 'C3 - M1M2','C3, A1-A2','C3-(A1-A2)','C3-(M1+M2)','C3-A1+A2','C3-M1,M2','C3/A2','C3A2', 'C3M1,M2','C3-A2','C3-A23456','C3-M2','C3-A2', 'EEG C3-A2', 'C3-M1', 'C3-A1', 'C3-x'};
                {'C4 - (M1+M2)','C4 - M1M2','C4,A1-A2','C4,M1,M2','C4-(A1-A2)','C4-(M1+M2)','C4-A1+A2','C4-M1,M2','C4/A1','C4A1','C4-A2','C4-M2','C4-A1','C4_A1','EEG C4-A1','C4-M1','C4-x'};
                {'FZ-A1/A2','FZ-A1A2','Fz-A2'};
                {'F1/A2','FP1-A2','FP1-AZ','FP1/A2','F1-A2'};
                {'FP1-C33456','FP1-T3','FP-?'};
                {'F2/A1','FP2-A1','F2-A1'};
                {'FP2-T4','F2-T4'};
                {'F3 - (M1+M2)','F3 - M1M2','F3, A1-A2','F3-(A1-A2)','F3-(M1+M2)','F3-A1+A2','F3-M1,M2','F3/A2','F3-AVG','F3-M2','EEG F3-A2','F3-x'};
                {'F4 - (M1+M2)','F4 - M1M2','F4, A1-A2','F4-(A1-A2)','F4-(M1+M2)','F4-A1+A2','F4-M1,M2','F4/A1','F4A1','F4-AVG','F4-M2','EEG F4-A1','F4-M1','F4-x'};
                {'EOG LEFT', 'EOG-L','EOG_L','EOG EOG L','EOG Au-hor-L','EOG Au-hor','LOC'};
                {'EOG RIGHT', 'EOG-R','EOG_R','EOG EOG R','EOG Au-hor-R','EOG Au-hor#2','Unspec Auhor','ROC'}; 
                {'LOC-A2','E1-M2', 'E1-M2','E1-M1','EOG LOC-A2', 'LEOG-AVG','LEOG-A2','LEOG-M2','LOC - (M1+M2)','LOC - A1','LOC - M1M2','LOC A1-A2','LOC FP1-A1+A2','LOC-(M1+M2)','LOC/A2','LOC-M2', 'LEOG-x'}; % 'E1-M2', 'E1-M1', are from french cohort
                {'ROC-A1','E2-M1', 'E2-M2','EOG ROC-A2', 'ROC-M1','REOG-A1','REOG-AVG','REOG-M1','REOG-M2','ROC - (M1+M2)','ROC - A1','ROC - M1M2','ROC A1-A2','ROC FP2-A1+A2','ROC-(M1+M2)','ROC/A1','REOG-x'}; 
                {'EOG-Both','Ocular','L/REOG'};                                                
                {'THERMISTOR','THRM','Oral','Oral Thermistor'};
                {'OXIMETRY','HRATE','Heartrate','Pulse','PULSE','PULS','PulseRate','Pulse Rate'};
                {'PTT','Pulse Transit Time'};                
                {'CPAP Tidal Volum','PAP tidal volume'};
                {'p Flow','CFLOW','CPAP Flow','PFLOW','P Flow','PAP Pt Flow','PAP Patient Flow'}
                {'Flow','AIRFLOW','Air Flow','AirFlow','Flow Patient','Airflow'};
                {'PES','Pes','Esophageal Pressure'};
                {'Nasal','Nasal Pressure'};
                {'CPRESS','C-PRES', 'PAP Pressure'};                
                {'LEAK','CPAP Leak', 'PAP Leak','PAP Leak'};                
                {'EtCO2','ETCO2','CO2 EndTidal', 'EtCO2'};
                {'pCO2','TcCO2'};                
                {'Oxygen Saturati','SAT','SpO2','SAO2','SaO2', 'SpO2'};
                {'MIC','Mic','MICRO','Sound Mic','Microphone'};
                };            
        end
    end
end