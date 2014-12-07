function [  ] = optiFinder(  )
% Optimum Finder for:
%   - move prob

rounds = 8;             % how many times it should use same inputs (=> stable data)

mp_start = .2;           % moveProb
mp_stop = .8;
mp_step = .1;

dataset = 2;
smallChanges = 0;
dropCounter = 2;
isAnimated = 0;

error_abs_M = zeros(1,round((mp_stop-mp_start)/mp_step+1));
error_abs_sum = 0;
u = 0;

set(0,'DefaultFigureVisible','off') % suppress bar graph output
for moveProb = mp_start:mp_step:mp_stop
    u = u+1;
    
    for j = 1:rounds
        error_abs = NaSch_Datasets_v1(dataset, moveProb, smallChanges, dropCounter, isAnimated);
        error_abs_sum = error_abs_sum + error_abs;
    end
    
    error_abs_M(1,u) = error_abs_sum/rounds;   % calculate mean of absolute error
end

% diagram of different errors
set(0,'DefaultFigureVisible','on') % do not suppress following bar graph output
figure()
hold on;
title('optiFinder')
x = mp_start:mp_step:mp_stop;
y = error_abs_M;
xlabel('moveProb');
ylabel('Absolute Error');
bar(x,y, 'EdgeColor','g', 'FaceColor','g')

end