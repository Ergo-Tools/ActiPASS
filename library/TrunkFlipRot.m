function [Acc,trnkOrient] = TrunkFlipRot(Acc,Fs,wlklgc,trunkrot,trunkflip)
%TRUNKFLIPROT try to automatically fix trunk orientations (also considers given orientations when in doubt)

% expand the wlklgc to full Acc length
wlklgc=repelem(wlklgc,Fs);
if mean(Acc(wlklgc,1))>0.7
    trunkrot=1;
elseif mean(Acc(wlklgc,1))< -0.7
    trunkrot=0;
end

trnkOrient=2*trunkrot+trunkflip+1;
% do the actual changes to Acc data based on orientations found
Acc = ChangeAxes(Acc,'Axivity',trnkOrient);
end

