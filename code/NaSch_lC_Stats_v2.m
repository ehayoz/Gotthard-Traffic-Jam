function congLength = NaSch_lC_Stats_v2(moveProb, inFlow, laneChange, N, isAnimated)

% INPUT: 
%   moveProb: the probability for a car to move forwards, 0..1
%   inFlow: The inflow volume to the road, 0..1
%   laneChange: the probability for a car to change the lane, 0..1
%   laneReduction: the probabilty for a car to change the lane at cC
%   N: road length (> 100)
% OUTPUT:
%   density: the average vehicle density, 0..1
%   flow: the average flow of cars, 0..1
% EXAMPLE:
%   NaSch_lC_Stats(.5,.4,.1,1000)

% set parameter values
cC = N-30;      % "change cell", where cars have to change the lane
nIter = 9000;   % number of iterations
vmax = 5;       % maximal velocity of the cars
L = 10;         % length of lane where cars can change (in front of cC)
vmax_L = 2;     % maximal velocity in L
a = 0.4;        % min probabilty that car changes lane at cC - L
b = 0.8;        % max probability that car changes lane at cC

% use quadratic increments for the probabilty between a and b (p = k*x^2+d) 
k = (a - b)/(L*L-2*cC*L);           % for x=cC-L is p = a
d = b - cC*cC*(a - b)/(L*L-2*cC*L); % for x=cC   is p = b


% define road (-1 = no car; 0..vmax = car, value  
% represents velocity)
%X = 4*(rand(2,N) < inFlow) - 1;     
%X(1,cC+1:N) = -ones(1,N-cC);        % no cars after lane reduction
X = -ones(2,N);

% set statistical variables
vSum = 0;       % sum of speeds
nCars = 0;      % #cars on road


% define variables in a block (2 x bL)
bL = 10;        % block length:   length of a block
bD = 0;         % block density:  density of cars in a block, 0..1
bV = 0;         % block velocity: average velocity in a block, 0..vmax
bC = 0;         % block counter:  counts number of blocks (congestion), 0..(N % bL)
bE = 0;         % empty counter:  counts number of blocks (no congestion), 0..2

% congestion length in each round
congLength = zeros(1, nIter);
congLength_prev = 10;

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
        if bV < 1  &&  bD > .7
           bC = bC + 1;
        
           bE = 0;
        elseif bE >= 1
           break
        elseif i == cC || i == cC - bL
           bE = bE + 1;
           bC = 0;
        else
           bE = bE + 1;
           bC = bC + 1;
        end

        % reset variables
        bV = 0;
        bD = 0;
    end
    congLength_curr = bC * bL;
    
    if congLength_prev < congLength_curr
       congLength(1,t) = congLength_prev + bL;
    elseif congLength_prev == congLength_curr
       congLength(1,t) = congLength_curr;
    else
       congLength(1,t) = congLength_prev - bL;
    end 
    congLength_prev = congLength(1,t);
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
        title([ 'Iterationsschritt: ' num2str(t), '  congestion: ' num2str(congLength(1,t)), '  Average Speed: ' num2str(vAverage)])

        for row = 1:2
            for i = N-100:N
                if X(row,i) ~= -1
                   draw_car(i, 1.2*(1.5-row), 0.8, 0.2);
                end
            end
        end

        pause(0.01)
    end
    
    if t > 6500
       inFlow = 0.15;
    end
    if t > 8000
       inFlow = 0;
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
figure() 
bar(congLength)
xlim([0 nIter])
