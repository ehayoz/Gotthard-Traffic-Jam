function [density, flow] = NaSch_LaneChange(moveProb, inFlow, laneChange, laneReduction, N)

% INPUT: 
%   moveProb: the probability for a car to move forwards, 0..1
%   inFlow: The inflow volume to the road, 0..1
%   laneChange: the probability for a car to change the lane, 0..1
%   laneReduction: the probabilty for a car to change the lane at cC
%   N: road length (>= 100)
% OUTPUT:
%   density: the average vehicle density, 0..1
%   flow: the average flow of cars, 0..1

% set parameter values
cC = N-30;      % "change cell", where cars have to change the lane
nIter = 250;    % number of iterations
vmax = 5;       % maximal velocity of the cars
L = 30;         % length of lane where cars can change (in front of cC)
vmax_L = 2;     % maximal velocity in cL
a = 0.2;        % min probabilty that car changes lane at cC - L
b = 1;          % max probability that car changes lane at cC

% use quadratic increments for the probabilty between a and b (p = k*x^2+d) 
k = (a - b)/(L*L-2*cC*L);           % for x=cC-L is p = a
d = b - cC*cC*(a - b)/(L*L-2*cC*L); % for x=cC   is p = b


% define road (-1 = no car; 0..vmax = car, value  
% represents velocity, cars start with v=2)
X = 3*(rand(2,N) < inFlow) - 1;     
X(1,cC+1:N) = -ones(1,N-cC);        % no cars after lane reduction

% set statistical variables

vAverage = 0;
jamLength = 0;
movedCars = 0;
density = 0;

% COUNTER
inflowCounter = 0;
outflowCounter = 0;

% count cars on lanes
for i = 1:2*N
    if X(i) ~= -1
       inflowCounter = inflowCounter + 1;
    end
end

%% main loop, iterating the time variable, t
for t = 1:nIter
    
    % cars change lane (left to right) with given probability laneChange
    for i = 1:cC-2
        if X(1,i) ~= -1  &&  X(2,i) == -1  &&  rand < laneChange
           X(2,i) = X(1,i);
           X(1,i) = -1;
        end
        if X(2,i) ~= -1  &&  X(1,i) == -1  &&  rand < 0.9*laneChange
           X(1,i) = X(2,i);
           X(2,i) = -1;
        end
    end
    
 
    
    % acceleration (NaSch -- RULE 1) ================
    for i = 1:2*N
        if X(i) ~= -1  &&  X(i) < vmax
           X(i) = X(i) + 1;
        end
    end

    % cars have to change lane due to lane reduction
    for i = cC-L:cC
        
        % reduce velocity of left lane
        if X(1,i) > vmax_L - 1
           X(1,i) = vmax_L - 1;
        end
        
        
        if X(1,i) ~= -1 % change lane if possible
           if X(2,i) == -1 && rand < (k*i*i + d)*laneReduction
              X(2,i) = X(1,i) + 2; % +2 accelerate
              X(1,i) = -1;
            
           elseif X(1,i)+i > cC % avoid overrunning changeCell
              X(1,i) = cC-i;
           end
        end
    end
    
    % slowing down (NaSch -- RULE 2) ================
    for row = 1:2
        for i = 1:N
            if X(row,i) ~= -1
               for j = 1:X(row,i)
                   if i+j <= N
                      if X(row,i+j) ~= -1
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

    % OUTFLOW -- count leaving cars
    for i = N:-1:N-vmax+1
        if X(2,i)+i > N
           outflowCounter = outflowCounter + 1;
           break
        end
    end

    
    % car motion (NaSch -- RULE 4) ==================
    
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
    
    % update position X(1,1) left lane (inflow left)
    % reduce inflow value for left lane
    if rand < 0.9*inFlow && X(1,1) == -1
       X(1,1) = vmax;
       inflowCounter = inflowCounter + 1;
    end
    % update position X(2,1) right lane (inflow right)
    if rand < inFlow && X(2,1) == -1
       X(2,1) = vmax;
       inflowCounter = inflowCounter + 1;
    end    

    % update statistics
    density = density + sum(X)/(2*N);
    
    % animate (this code + draw_car.m is from class)
    clf; hold on;
    plot(0:cC+1, 0.5*ones(1,cC+2), 'Color', [.75 .75 .75], 'LineWidth', 12)
    plot(0:N+1, -0.5*ones(1,N+2), 'Color', [.75 .75 .75], 'LineWidth', 12)
    xlim([0 N+1])
    ylim([-N/4 N/4])
    title([ 'Nagel-Schreckenberg Modell   --    Iterationsschritt ' num2str(t)])
    for row = 1:2
        for i=1:N
            if X(row,i) ~= -1
               draw_car(i, (1.5-row)*0.9, 0.8, 0.2);
            end
        end
    end
    
    pause(.05)
    
end
%% END OF MAIN LOOP

% OUTFLOW -- count remaining cars on lanes
for i=1:2*N
    if X(i) ~= -1
    outflowCounter = outflowCounter + 1;
    end
end
 
% check if inflow is equal to outflow
if outflowCounter == inflowCounter
   title([ 'Nagel-Schreckenberg Modell   --    Iterationsschritt ' num2str(t) '   --    inflow = outflow = ' num2str(outflowCounter)])
else
   title([ 'Nagel-Schreckenberg Modell   --    Iterationsschritt ' num2str(t) '   --    error occured: inflow and outflow are different!!!'])
end

% rescale statistical vaiables before returing them
density = density/nIter;
flow = movedCars/(2*N*nIter);
