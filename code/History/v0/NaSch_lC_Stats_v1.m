function t = NaSch_lC_Stats_v1(moveProb, inFlow, laneChange, N, isAnimated)

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
emptyCount = 0;
first = 1;
lT = .75;        % lower threshold for congLength fluctuation
uT = 1.25;       % upper threshold for congLength fluctuation
cT = 50;        % threshold for interpolating congLength
congStart = 0;
congLength = 0;
congLength1 = 0;
congLength2 = 0;
congLengthPrev1 = cT; % "default" congLengthPrev
congLengthPrev2 = cT; % "default" congLengthPrev
lengthAverage = zeros(1, nIter);

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
    
    % length of congestion
    % traffic congestion: during 60s and more, less than 10km/h (v <= 3)
    for row = 1:2
        for i = cC:-1:1 % combustion can only begin at cC (traffic in tunnel is fluent)
            if X(row,i) == -1
               emptyCount = emptyCount + 1; % count empty cells between cars
            else
               emptyCount = 0;
            end
            
            if 0 <= X(row,i) && X(row,i) <= 3 && first == 1 % detect potential congestion
               congStart = i;
               first = 0;
               emptyCount = 0;
            elseif X(row,i) >= 4 || emptyCount >= 4 % no congestion anymore
               first = 1;
               congEnd = i;
               congLength = congStart - (congEnd + emptyCount);
               break % measure only congLength directly in front of Gotthard
            end
        end
        
        
        if row == 1 && congLength > cT % distinguish both rows
            if lT*congLengthPrev1 < congLength && congLength < uT*congLengthPrev1 % prevent extreme fluctuation
                congLength1 = congLength;
            else
                congLength1 = congLengthPrev1;
            end
            
        elseif row == 2 && congLength > cT
            if lT*congLengthPrev2 < congLength && congLength < uT*congLengthPrev2 % prevent extreme fluctuation
                congLength2 = congLength;
            else
                congLength2 = congLengthPrev2;
            end
        end   
    end
    
    % average length
    lengthAverage(1,t) = .5 * (congLength1 + congLength2);
       
    %% animation
    if isAnimated
        clf; hold on;
        xlim([N-100 N+1])
        ylim([-20 20])
        plot(N-100:cC+1, 0.5*ones(1,length(N-100:cC+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:N+1, -0.5*ones(1,length(N-100:N+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:cC+1, 0*(N-100:cC+1), '--', 'Color', [.95 .95 .95], 'LineWidth', .8)
        title([ 'Iterationsschritt: ' num2str(t), '  Length1: ' num2str(congLength1), '  Length2: ' num2str(congLength2), '  Average Length: ' num2str(lengthAverage(1,t)), '  Average Speed: ' num2str(vAverage)])

        for row = 1:2
            for i = N-100:N
                if X(row,i) ~= -1
                   draw_car(i, 1.2*(1.5-row), 0.8, 0.2);
                end
            end
        end

        pause(0.01)
    end
    
    if t > 3500
       inFlow = 0.15;
    end
    if t > 4000
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
bar(lengthAverage)
