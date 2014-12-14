function [moveProb, moveCorr] = optiFinder(dataset)
% Optimum Finder for:
%   - moveProb
%   - moveCorr

%% moveCorr
mc_start = .033;
mc_stop = .066;
mc_step = .033;

%% moveProb
mp_start = .45;
mp_stop = .55;
mp_step = .05;

isAnimated = 0;
rounds = 1;
numberMC = round((mc_stop-mc_start)/mc_step+1);
numberMP = round((mp_stop-mp_start)/mp_step+1);
evaluation = zeros(2,numberMC * numberMP);
precision_tot = 0;
prediction_tot = 0;
v = 0;

set(0,'DefaultFigureVisible','off') % suppress bar graph output
for moveProb = mp_start:mp_step:mp_stop
 for moveCorr = mc_start:mc_step:mc_stop
     v = v+1;
   for j = 1:rounds
       [precision,prediction]  = NaSch_Datasets_v1(dataset, moveProb, isAnimated, moveCorr);
       precision_tot = precision_tot + precision;
       prediction_tot = prediction_tot + prediction;   
   end
   evaluation(1,v) = precision_tot/rounds;
   evaluation(2,v) = prediction_tot/rounds;
   precision_tot = 0;
   prediction_tot = 0;
 end
end
% diagram of different errors
set(0,'DefaultFigureVisible','on') % do not suppress following bar graph output
figure()
hold on;
title('optiFinder - Precision')
x = 1:length(evaluation);
y = evaluation(1,:);
xlabel('Parameter setting');
ylabel('Precision');
bar(x,y, 'EdgeColor','g', 'FaceColor','g')

figure()
hold on;
title('optiFinder - Prediction')
x = 1:length(evaluation);
y = evaluation(2,:);
xlabel('Parameter setting');
ylabel('Prediction');
bar(x,y, 'EdgeColor','g', 'FaceColor','g')

figure()
hold on;
title('optiFinder - Precision : Prediction (3:1)')
x = 1:length(evaluation);
y = (3*evaluation(1,:)+evaluation(2,:))/4;
xlabel('Parameter setting');
ylabel('Precision : Prediction (3:1)');
bar(x,y, 'EdgeColor','g', 'FaceColor','g')

[Max, Index] = max(y);
T = zeros(numberMC, numberMP);
T(Index) = 1;
[value, location] = max(T(:));
[R,C] = ind2sub(size(T),location);
moveProb = mp_start + (C-1) * mp_step;
moveCorr = mc_start + (R-1) * mc_step;
end
