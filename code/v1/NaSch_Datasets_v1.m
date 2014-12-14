function [error] = NaSch_Datasets_v1(dataset, moveProb, isAnimated, moveCorr)

% values
% NaSch_Datasets_v1(1,.525,0,0,0,.055): perfectly symmetric
% NaSch_Datasets_v1(2,.525,0,0,0,.05):  less error

%% parameters
% INPUT:
%   dataset: choose one of 4 datasets, {1,2,3,4} (don't use 3,4:evaluation)
%   moveProb: the probability for a car to move forwards, 0..1
%   isAnimated: start program with animation, boolean 1=true 0=false
% OUTPUT:
%   error_tot:  total
%
% EXAMPLE:
%   NaSch_lC_Stats_v1(2, .5, 0 , 1, 0)

% parameters for comparison model - reality
lC = 4.5;                % length of each cell (average length of cars => Skoda Octavia)
lR = 19000;              % length in Reality (Erstfeld - Goeschenen, 13min)
N = round(lR / lC);      % 4222 cells
measureInterval = 30;    % measure every #min
[I, S] = Datasets(dataset);
nIter = length(I)*180;   % number of iterations; datasets: #cars/180s => we want 1 iteration / s
q = 0;                   % running variable for reading outSet
redLight_act = 1;        % activate redLight

% set parameter values
conv = 1000/lC;    % "convert", #cells that matches 1km
cC = N-22;         % "change cell", where cars have to change the lane
vmax = 5;          % maximal velocity of the cars (vmax = 5 = 100 km/h)
L = 11;            % length of lane where cars can change (in front of cC)
vmax_L = 3;        % maximal velocity in L
a = 0.2;           % min probabilty that car changes lane at cC - L
b = 0.6;           % max probability that car changes lane at cC
laneChange = .1;   % the probability for a car to change the lane, 0..1
dropCounter = 2;   % dropCounter: #seconds a car can pass the redlight, redlight is active
                   % after 2km congestion. Use '1' to turn off redlight. Do NOT
                   % use odd numbers.
redLight = 0;      % automatic redLight, do NOT turn on
inflowCounter = 0; % count cars

% use quadratic increments for the probabilty between a and b (p = k*x^2+d)
k = (a - b)/(L*L-2*cC*L);            % for x=cC-L is p = a
d = b - cC*cC*(a - b)/(L*L-2*cC*L);  % for x=cC   is p = b

% set statistical variables
vSum = 0;        % sum of speeds
nCars = 0;       % #cars on road

% define variables in a block (2 x bL)
bL = 50;         % block length:   length of a block // 225m
bD = 0;          % block density:  density of cars in a block, 0..1
bV = 0;          % block velocity: average velocity in a block, 0..vmax
bC = 0;          % block counter:  counts number of blocks (congestion), 0..(N % bL)
bE = 0;          % empty counter:  counts number of blocks (no congestion), {0,1,2}

% congestion length in each round
if mod(dataset,2)
    divider = 48*60 / measureInterval;
else
    divider = 24*60 / measureInterval;
end
congLength = zeros(1,nIter/divider);
congPlot = zeros(1,divider); 
currentCongestion = 0;
first = 1;                           % congestion optimization
opt_act = 0;
congStart = 0;

% define road (-1 = no car; 0..vmax = car, value represents velocity)
X = -ones(2,N);

% take average inflow (every 2 hours)
if mod(dataset,2)
    inflow = zeros(1,24);
    for i = 0:23
        inflow(1,i+1) = sum(I(1,1+i*40:40+i*40)) / 40;
    end
else
    inflow = zeros(1,12);
    for i = 0:11
        inflow(1,i+1) = sum(I(1,1+i*40:40+i*40)) / 40;
    end
end
p=1;

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
        % right to left --> probabilty 0.95*laneChange
        if X(2,i) ~= -1  &&  X(1,i) == -1  &&  rand < 0.95*laneChange
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
        
        % reduce velocity of lanes in front of lane reduction
        if X(1,i) > vmax_L
            X(1,i) = vmax_L;
        elseif X(2,i) > vmax_L
            X(2,i) = vmax_L;
        end
        
        % lane change on road
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
    
    % red light
    if X(1,cC-10) ~= -1 && redLight
        X(1,cC-10) = 0;
        if mod(t+dropCounter/2,dropCounter) == 0
            X(1,cC-10) = 2;
        end
    end
    
    if X(2,cC-10) ~= -1 && redLight
        X(2,cC-10) = 0;
        if mod(t,dropCounter) == 0
            X(2,cC-10) = 2;
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
    
    % car motion (NaSch -- RULE 4) ==================
    
    %% inflow
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
    
    if t > q*180 % datasets: #cars / 180s => every 180s we take new inflow value from dataset
        q = q + 1;
        
        % average inflow
        if mod(q,40) == 0
           p = p + 1;
        end
        
        if mod(dataset,2)
            if p > 24
               p = 24;
            end
        else
            if p > 12
               p = 12;
            end
        end
        rateI = inflow(1,p)/(2*180);   

        rateS_m = S(1,q); % mean speed
        rateS_m = rateS_m/(3.6*5.55555); % convert km/h into NaSch-units
        if rateS_m > 5
            rateS_m = 5;
        elseif rateS_m < 2
            rateS_m = 2;
        end
    end
INFLOWMATRIX(1,t) = rateI;
    rateS = ceil(rateS_m) - (rand < (ceil(rateS_m)-rateS_m));
    
    % update position X(1,1) left lane (inflow left)
    % calculate inflow rate per second, divide by 2 because
    % the 2 rows, multiply by .95 because left lane
    rate = rateI*.95; 
    
    if rand < rate && X(1,1) == -1
        X(1,1) = rateS;  % all cars enter with speed of rateS
        inflowCounter = inflowCounter + 1;
    end
    
    % update position X(2,1) right lane (inflow right)
    rate = rateI*1.05;
    
    if rand < rate && X(2,1) == -1
        X(2,1) = rateS;  % all cars enter with speed of rateS
        inflowCounter = inflowCounter + 1;
    end
    
    %% statistics
    % average speed (only with animation)
    if isAnimated
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
    end
    
    % congestion length
    for i = cC:-bL:1
        % compute density of cars and average velocity in a block
        for j = 2*i:-1:2*(i-bL) + 1
            if X(j) ~= -1
                bV = bV + X(j);
                bD = bD + 1;
            end
        end
        if bD == 0
            bD = 1;
        end
        bV = bV / bD;
        bD = bD / (2*bL);
        
        % test if block satisfy conditions for a congenstion
        % count only connected congestion, gaps are allowed.
        % gap is #gaps allowed between two 'congestion-blocks'
        gap = 1;
        if bV < 1  &&  bD > .48
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
    
    k = measureInterval * 60;
    congLength(1,1+mod(t-1,k)) = bC * bL;
    % measure congestion for interval[min], store mean in congPlot
    if mod(t,k) == 0
        congPlot(1,t/k) = sum(congLength/conv) / k;
        %congPlot(1,t/k) = round((sum(congLength/conv) / k)/.5)*.5;    % round half up
        
        % "traffic optimization" (faster congestion growth at beginning)
        if congPlot(1,t/k) > 1 && first == 1
           moveProb = moveProb + moveCorr;       % slow down moveProb when congestion begins
           first = 0;
           congStart = t;
           opt_act = 1;
        end
        
        % enable redlight, if congestion longer than 1km
        if congPlot(1,t/k) > 1 && redLight_act
            redLight = 1;
        else
            redLight = 0;
        end
        currentCongestion = congPlot(1,t/k);
    end
    
    % reset moveProb after x*3600 seconds
    if t >= congStart + 2*3600  &&  currentCongestion < 2  &&  opt_act
       moveProb = moveProb - moveCorr;
       first = 0;
       opt_act = 0;
    end
    
    % reset counters
    bC = 0;
    bE = 0;
    
    %% animation
    if isAnimated
        %clf; 
        hold on;
        xlim([N-100 N+1])
        ylim([-20 20])
        plot(N-100:cC+1, 0.5*ones(1,length(N-100:cC+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:N+1, -0.5*ones(1,length(N-100:N+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:cC+1, 0*(N-100:cC+1), '--', 'Color', [.95 .95 .95], 'LineWidth', .8)
        title([ 'Iterationsschritt: ' num2str(t), '  Congestion: ' num2str(currentCongestion), '  Average Speed: ' num2str(vAverage), '  inFlow: ' num2str(rateI)])
        
        for row = 1:2
            for i = N-100:N
                if X(row,i) ~= -1
                    draw_car(i, 1.2*(1.5-row), 0.8, 0.2);
                end
            end
        end       
        pause(0.01)
    end
end
%% END OF MAIN LOOP

disp (['inflow and outflow are equal to ' num2str(inflowCounter)]);


% diagram of comparison model - reality
[Y_dataset, data] = interpolate(dataset, measureInterval, 0);
figure
hold on;
title(' Comparison Model - Reality ')
xval = measureInterval / 60;
bar(xval:xval:nIter/3600,congPlot);
bar(xval:xval:nIter/3600,Y_dataset, .4, 'FaceColor',[.8,.85,.9])

ylim([0 16]);
if mod(dataset,2)
    xlabel([datestr(data(1,:),'dd.mm.yyyy') ' - ' datestr(data(end,:),'dd.mm.yyyy')]);
else
    xlabel(datestr(data(1,:),'dd.mm.yyyy'));
    if dataset == 2
       ylim([0 6]);
    end
end
ylabel('Kilometer');
if mod(dataset,2)
    xlim([0 48]);
else
    xlim([0 24]);
end
grid on;
hold off;

%% error evaluation
area_dataset = xval * sum(Y_dataset);
error = 0;
for i = 1:length(congPlot)
    error = error + xval*abs(congPlot(i)-Y_dataset(i));
end
error =  error / area_dataset;
precision = 1 - error

figure()
bar(1:nIter, INFLOWMATRIX)
end

%% datasets
function [InFlow, Speed] = Datasets(inSet)
switch inSet
    case 1
        InFlow = csvread('Dataset.csv', 2,   1, 'B3..B962')';
        Speed  = csvread('Dataset.csv', 2,   2, 'C3..C962')';
    case 2
        InFlow = csvread('Dataset.csv', 2,   5, 'F3..F482')';
        Speed  = csvread('Dataset.csv', 2,   6, 'G3..G482')';
    case 3
        InFlow = csvread('Dataset.csv', 2,   3, 'D3..D962')';
        Speed  = csvread('Dataset.csv', 2,   4, 'E3..E962')';
    case 4
        InFlow = csvread('Dataset.csv', 482,   5, 'F483..F962')';
        Speed  = csvread('Dataset.csv', 482,   6, 'G483..G962')';
end
end
