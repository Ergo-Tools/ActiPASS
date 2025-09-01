function   VrefTrunk = EstimateRefTrunk1(firstDay,Vtrunk,SF,Akt,OffTrunk,VrefTrunkDef) 

% Estimation of reference angle for trunk accelerometer.
% Trunk reference angle is estimeated for each interval in the setup file. The calculation is based on 
% an investigation of 50 measurements from the BAuA project, in which is was found that 
% the average difference between the trunk angle during walk and upright standing was 6 (+/-6) degrees (29/5-19)
 
 persistent oldRef
 if firstDay  %first interval for ID: provisionel reference
   oldRef=VrefTrunkDef;
 end
 VtrunkAccAP = median(reshape(Vtrunk(:,2),SF,length(Akt))); %ant/pos accelerometer angle 
 VtrunkAccLat = median(reshape(Vtrunk(:,3),SF,length(Akt))); %lat accelerometer angle
 v2 = median(VtrunkAccAP(Akt==5 & ~OffTrunk')) - pi*6/180;
 v3 = median(VtrunkAccLat(Akt==5 & ~OffTrunk'));
 VrefTrunk = [acos(cos(v2)*cos(v3)),v2,v3]; %sfærisk triangle
 if isnan(v2) || sum(Akt==5 & ~OffTrunk')<60 %less than ½ minute is not accepted
     VrefTrunk = oldRef; %no walking, use previous value 
 else
     oldRef = VrefTrunk;
 end
