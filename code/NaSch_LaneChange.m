function [density, flow] = NaSch_LaneChange(moveProb, inFlow, laneChange)

% INPUT: 
%   moveProb: the probability for a car to move forwards, 0..1
%   inFlow: The inflow volume to the road, 0..1
%   laneChange: the probability for a car to change the lane, 0..1

% OUTPUT:
%   density: the average vehicle density, 0..1
%   flow: the average flow of cars, 0..1


% set parameter values
N = 100;           % road length
C = 50;            % "Change cell", where cars have to change the lane
nIter = 1000;      % number of iterations
vmax = 5;          % maximal velocity of the cars

% define road (-1 = no car; 0..vmax = car, value  
% represents velocity, cars start with v=2)
X = 3*(rand(2,N) < inFlow) - 1;

% set statistical variables
movedCars = 0;
density = 0;

% main loop, iterating the time variable, t
for t = 1:nIter
    
    % acceleration (NaSch -- RULE 1) ================
    for i = 1:2*N
        if X(i) >= 0 && X(i) < vmax
           X(i) = X(i) + 1;
        end
    end

    % slowing down (NaSch -- RULE 2) ================
    for row = 1:2
        for i = 1:N
            if X(row,i) >= 0
               for j = 1:X(row,i)
                   if i+j <= N
                      if X(row,i+j) >= 0
                         X(row,i) = j-1;
                         break
                      end
                   end
                end
            end
        end
    end
        
    % randomization (NaSch -- RULE 3) ===============
    for i = 1:2*N
        if X(i) > 0
           X(i) = X(i) - (rand > moveProb);
        end
    end

    % car motion (NaSch -- RULE 4) ==================

    % lane change
    % until cell C cars change to right lane with probability laneChange
    for i = 1:(C-1)
        if X(2,i) ~= -1  % just for cells with car in it
            if X(1,i) == -1  % if there is no neighbour
                if rand < laneChange
                    X(1,i) = X(2,i);    % change lane
                    X(2,i) = -1;
                end
            end
        end
    end
            
    % if a car could overrun cell C in next round there is a "forced lane
    % change"
    for i = C:-1:C-10            % find cars which could overrun C
        if X(2,i) ~= -1
            if X(1,i) == -1         % if there is no neighbour
                X(1,i) = X(2,i);    % change lane
                X(2,i) = -1;
                
            elseif (X(1,i) + i) > C-5  % check if neighbours prevent change
                X(1,i) = C - 5 - i; % slow down speed to distance betw. C-1&i
                                    % create spot for next round
            end
        end
    end
        
    
    % update positions X(1..N)    
    Xold = X;
    for row = 1:2
        for i = 1:N
            if Xold(row,i) > 0 && i + Xold(row,i) <= N
               X(row,i+X(row,i)) = X(row,i);
               X(row,i) = -1;
               % keep track of how many cars are moved forwards.
               % Needed for calculating the flow later on.
               movedCars = movedCars + 1;
            elseif Xold(row,i) > 0 && i + Xold(row,i) > N
               X(row,i) = -1;
            end
        end
    end
    
    % update position X(1) (inflow)
    for row = 1:2
        if rand < inFlow
           X(row,1) = vmax;
        end
    end
    
    % update statistics
    density = density + sum(X)/(2*N);
    
    % animate (this code + draw_car.m is from class)
    clf; hold on;
    plot(0:N, 0*(0:N), 'Color', [.75 .75 .75], 'LineWidth', 25)
    title([ 'Nagel-Schreckenberg Modell   --    Iterationsschritt ' num2str(t)])
    xlim([0 N+1])
    ylim([-N/4 N/4])
    for row = 1:2
        for i=1:N
            if X(row,i) >= 0
               draw_car(i, (row-1.5)*0.9, 0.8, 0.2);
            end
        end
    end
    
    pause(.1)
    
end

% rescale statistical vaiables before returing them
density = density/nIter;
flow = movedCars/(2*N*nIter);
