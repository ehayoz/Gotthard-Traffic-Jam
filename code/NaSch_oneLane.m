function [density, flow] = NaSch_oneLane(moveProb, inFlow)

% INPUT: 
%   moveProb: the probability for a car to move forwards, 0..1
%   inFlow: The inflow volume to the road, 0..1

% OUTPUT:
%   density: the average vehicle density, 0..1
%   flow: the average flow of cars, 0..1


% set parameter values
N = 100;           % road length
nIter = 1000;      % number of iterations
vmax = 5;          % maximal velocity of the cars

% define road (-1 = no car; 0..vmax = car, value represents velocity)
X = -ones(1,N) + 3*(rand(1,N) < inFlow);

% set statistical variables
movedCars = 0;
density = 0;

% main loop, iterating the time variable, t
for t = 1:nIter
    
    % acceleration (NaSch -- RULE 1) ================
    for i = 1:N
        if X(i) >= 0 && X(i) < vmax
           X(i) = X(i) + 1;
        end
    end

    % slowing down (NaSch -- RULE 2) ================
    for i = 1:N
        if X(i) >= 0
           for j = 1:X(i)
               if i+j <= N
                  if X(i+j) >= 0
                     X(i) = j-1;
                     break
                  end
               end
           end
        end
    end
        
    % randomization (NaSch -- RULE 3) ===============
    for i = 1:N
        if X(i) > 0
           X(i) = X(i) - (rand > moveProb);
        end
    end

    % car motion (NaSch -- RULE 4) ==================

    % update positions X(1..N)
    
    Xold = X;
    for i = 1:N
        if Xold(i) > 0 && i + Xold(i) <= N
           X(i+X(i)) = X(i);
           X(i) = -1;
           % keep track of how many cars are moved forwards. 
           % Needed for calculating the flow later on.
           movedCars = movedCars + 1; 
        elseif Xold(i) > 0 && i + Xold(i) > N
           X(i) = -1;
        end
    end            
            
    % update position X(1) (inflow)
    if rand < inFlow
        X(1) = vmax;
    end
    
    % update statistics
    density = density + sum(X)/N;

    
    % animate (this code + draw_car.m is from class)
    clf; hold on;
    plot(0:N, 0*(0:N), 'Color', [.75 .75 .75], 'LineWidth', 10)
    title([ 'Nagel-Schreckenberg Modell   --    Iterationsschritt ' num2str(t)])
    xlim([0 N+1])
    ylim([-N/4 N/4])
    for i=1:N
        if X(i) >= 0 && X(i) < vmax
           draw_car(i, 0, 0.8, 0.2);
        end
    end
    pause(.08)
end

% rescale statistical vaiables before returing them
density = density/nIter;
flow = movedCars/(N*nIter);
