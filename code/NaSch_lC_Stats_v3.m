function congLength = NaSch_lC_Stats_v3(moveProb, smallChanges, isAnimated)

% INPUT: 
%   moveProb: the probability for a car to move forwards, 0..1
%   smallChanges: do small changes for congestion measuring, 0..1, 0 is off
%   isAnimated: start program with animation, boolean 1=true 0=false
% OUTPUT:
%   congLength: array with congestion length
% EXAMPLE:
%   NaSch_lC_Stats_v3(.6,0,0)

% set parameter values
N = 4000;       % length of street, 235 = 1km
conv = 235;     % "convert", #cells that matches 1km
cC = N-30;      % "change cell", where cars have to change the lane
nIter = 86400;  % number of iterations, one iterations is equal to 1s
inFlow = .1;    % default inFlow
vmax = 5;       % maximal velocity of the cars
L = 15;         % length of lane where cars can change (in front of cC)
vmax_L = 2;     % maximal velocity in L
a = 0.3;        % min probabilty that car changes lane at cC - L
b = 0.7;        % max probability that car changes lane at cC
laneChange = .1;% the probability for a car to change the lane, 0..1

% use quadratic increments for the probabilty between a and b (p = k*x^2+d) 
k = (a - b)/(L*L-2*cC*L);           % for x=cC-L is p = a
d = b - cC*cC*(a - b)/(L*L-2*cC*L); % for x=cC   is p = b

% set statistical variables
vSum = 0;       % sum of speeds
nCars = 0;      % #cars on road

% define variables in a block (2 x bL)
bL = 100;       % block length:   length of a block
bD = 0;         % block density:  density of cars in a block, 0..1
bV = 0;         % block velocity: average velocity in a block, 0..vmax
bC = 0;         % block counter:  counts number of blocks (congestion), 0..(N % bL)
bE = 0;         % empty counter:  counts number of blocks (no congestion), 0..2

% congestion length in each round
congLength = zeros(1, nIter/36); % 2400s = 40min are 1/36 of 1 day
congLength_prev = 0;
congPlot = zeros(1,36); % final values for plotting
currentCongestion = 0;

% COUNTER
inflowCounter = 0;
outflowCounter = 0;

% define road (-1 = no car; 0..vmax = car, value represents velocity)
X = -ones(2,N);

%% main loop, iterating the time variable, t
for t = 1:nIter
    %% NaSch and laneChange
    % cars change lane with given probability laneChange
    for i = 1:cC-L
        % left to right --> probabilty laneChange
        if X(1,i) ~= -1  &&  X(2,i) == -1  &&  rand < laneChange
           X(2,i) = X(1,i);
           X(1,i) = -1;
        end
        % right to left --> probabilty 0.9*laneChange
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
        if X(1,i) > vmax_L
           X(1,i) = vmax_L;
        end
           
        if X(1,i) ~= -1 % change lane if possible
           if i == cC  &&  X(2,i) == -1
              X(2,i) = X(1,i) + 2;      % accelerate after lane change
              X(1,i) = -1;  
           elseif X(2,i) == -1 && rand < (k*i*i + d)
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
            elseif Xold(row,i) > 0 && i + Xold(row,i) > N
                X(row,i) = -1;
            end
        end
    end
    
    % update position X(1,1) left lane (inflow left)
    % reduce inflow value for0.1 left lane
    if rand < 0.9*inFlow && X(1,1) == -1
        X(1,1) = vmax;
        inflowCounter = inflowCounter + 1;
    end
    % update position X(2,1) right lane (inflow right)
    if rand < inFlow && X(2,1) == -1
        X(2,1) = vmax;
        inflowCounter = inflowCounter + 1;
    end
    
    
    %% statistics
    % average speed
    for row = 1:2
        for i = 1:cC
            if X(row,i) ~= -1
                vSum = vSum + X(row,i);
                nCars = nCars + 1;
            end
        end
    end
    
    vAverage = vSum / nCars;
    % reset vSum for next round
    vSum = 0;
    nCars = 0;
    
    % congestion length
    for i = cC:-bL:1
        % compute density of cars and average velocity in a block
        for j = 2*i:-1:2*(i-bL)
            if X(i) ~= -1
               bV = bV + X(i);
               bD = bD + 1;
            end
        end
        bV = bV / bD;
        bD = bD / (2*bL);
        
        % test if block satisfy conditions for a congenstion
        % count only connected congestion, gaps are allowed.
        gap = 2;
        if bV < 1.1  &&  bD > .7
           bC = bC + 1;
           bE = 0;
        elseif bE >= gap
           bC = bC - gap;
           break
        else
           bE = bE + 1;
           bC = bC + 1;
        end
        % reset variables
        bV = 0;
        bD = 0;
    end
    congLength(1,1+mod(t-1,2400)) = bC * bL;
    
     % allow only small changes! 
     if smallChanges 
        if congLength(1, 1+mod(t-1,2400)) > congLength_prev
           congLength(1, 1+mod(t-1,2400)) = congLength_prev + smallChanges;
        elseif congLength(1, 1+mod(t-1,2400)) < congLength_prev
           congLength(1, 1+mod(t-1,2400)) = congLength_prev - smallChanges;
        else
           congLength(1, 1+mod(t-1,2400)) = congLength_prev;
        end
        congLength_prev = congLength(1, 1+mod(t-1,2400));
    end
    
    % mesure congestion for 40min, store average in congPlot
    if mod(t,2400) == 0 
       congPlot(1,t/2400) = sum(congLength/conv)/2400;
       currentCongestion = congPlot(1,t/2400);
    end
    % reset counters
    bC = 0;
    bE = 0;
    
    %% animation
    if isAnimated
        clf; hold on;
        xlim([N-100 N+1])
        ylim([-20 20])
        plot(N-100:cC+1, 0.5*ones(1,length(N-100:cC+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:N+1, -0.5*ones(1,length(N-100:N+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:cC+1, 0*(N-100:cC+1), '--', 'Color', [.95 .95 .95], 'LineWidth', .8)
        title([ 'Iterationsschritt: ' num2str(t), '  congestion: ' num2str(currentCongestion), '  Average Speed: ' num2str(vAverage)])

        for row = 1:2
            for i = N-100:N
                if X(row,i) ~= -1
                   draw_car(i, 1.2*(1.5-row), 0.8, 0.2);
                end
            end
        end

        pause(0.01)
    end
  
    
% inFlow
    if t > 4*3600
       inFlow = 0.2;
    end
    if t > 5*3600
       inFlow = 0.4;
    end
    if t > 6*3600
        inFlow = 0.6;
    end
    if t > 8*3600
       inFlow = .8;
    end
    if t > 9*3600
       inFlow = 1;
    end
    if t > 10*3600
       inFlow = 0.55;
    end
    if t > 12*3600
       inFlow = .4;
    end
    if t > 13*3600  
       inFlow = 0.3;
    end
    if t > 17* 3600
       inFlow = .1;
    end
    if t > 19*3600
       inFlow = 0.05;
    end
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
   disp num2str(outflowCounter)
else
   disp 'error occured: inflow and outflow are different!!!'
end

% diagram of congestion
figure()
bar(2/3:2/3:24,congPlot)
title('Congestion')
xlabel('Anzahl Stunden -- gemessen alle 40min');
ylabel('Kilometer');
xlim([0 24]);
