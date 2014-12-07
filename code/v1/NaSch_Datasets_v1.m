function [ error_tot ] = NaSch_Datasets_v1(dataset, moveProb, smallChanges, redLight_act, isAnimated)
%% parameters
% INPUT:
%   dataset: choose one of 4 datasets, {1,2,3,4} (don't use 3,4:evaluation)
%   moveProb: the probability for a car to move forwards, 0..1
%   smallChanges: do small changes for congestion measuring, 0..1, 0 is off
%   redLight_act: enable/disable red light (0 off, 1 on)
%   isAnimated: start program with animation, boolean 1=true 0=false
% OUTPUT:
%   error_tot:  total
%
% EXAMPLE:
%   NaSch_lC_Stats_v1(2, .5, 0 , 1, 0)

% parameters for comparison model - reality
lC = 4.5;       % length of each cell (average length of cars => Skoda Octavia)
lR = 19000;     % length in Reality (Erstfeld - Goeschenen, 13min)
N = round(lR / lC); % 4222 cells
[I, S, T] = Datasets(dataset);   % length = 960
nIter = length(I)*180;   % number of iterations; datasets: #cars/180s => we want 1 iteration / s
q = 0;          % running variable for reading outSet

% set parameter values
conv = 1000/lC;  % "convert", #cells that matches 1km
cC = N-22;       % "change cell", where cars have to change the lane
vmax = 5;        % maximal velocity of the cars (vmax = 5 = 100 km/h)
L = 15;          % length of lane where cars can change (in front of cC)
vmax_L = 3;      % maximal velocity in L
a = 0.3;         % min probabilty that car changes lane at cC - L
b = 0.7;         % max probability that car changes lane at cC
laneChange = .1; % the probability for a car to change the lane, 0..1
dropCounter = 2; % dropCounter: #seconds a car can pass the redlight, redlight is active
                 % after 2km congestion. Use '1' to turn off redlight. Do NOT
                 % use odd numbers.
redLight = 0;    % automatic redLight, do NOT turn on

% use quadratic increments for the probabilty between a and b (p = k*x^2+d)
k = (a - b)/(L*L-2*cC*L);           % for x=cC-L is p = a
d = b - cC*cC*(a - b)/(L*L-2*cC*L); % for x=cC   is p = b

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
    divider = 72;
else
    divider = 36;
end
congLength = zeros(1,nIter/divider); % 2400s = 40min are 1/72 of 2 days
congLength_prev = 0;                 % 2400s = 40min are 1/36 of 1 day
congPlot = zeros(1,divider);         % final values for plotting
currentCongestion = 0;
cong_r_prev = 0;                     % real cong length
u = 1;
z = 0;
INFLOWMATRIX = zeros(1,nIter);

% COUNTER
inflowCounter = 0;
outflowCounter = 0;

% define road (-1 = no car; 0..vmax = car, value represents velocity)
X = -ones(2,N);


%%%%%%%%%%%%%%%%%% average inflow (every 2h(48) 1/2h(24) %%%%
%%{
if mod(dataset,2)
    inflow = zeros(1,24);
    for i = 0:23
        inflow(1,i+1) = sum(I(1,1+i*40:40+i*40)) / 40;
    end
else
    inflow = zeros(1,48);
    for i = 0:47
        inflow(1,i+1) = sum(I(1,1+i*10:10+i*10)) / 10;
    end
end
p=1;
%}

%%%%%%%%%%%%%%%%%% filter inflow %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rateI_prev = I(1,1)/(2*180);
iC = .3; % inFlow Change: rate between changes are allowed

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
    
    % OUTFLOW -- count leaving cars
    for i = N:-1:N-vmax+1
        if X(2,i)+i > N
            outflowCounter = outflowCounter + 1;
            break
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
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% average inflow %%%%%%%%%%%%%%%%%%%%%%
        %%{
        if mod(dataset,2)
            if mod(q,40) == 0
                p = p + 1;
            end
            if p > 24
                p = 24;
            end
        else
            if mod(q,10) == 0
                p = p + 1;
            end
            if p > 48
                p = 48;
            end
        end
        rateI = inflow(1,p)/(2*180);
        %}
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%% filter inflow %%%%%%%%%%%%%%%%%%%%%%%
        %{
        rateI = I(1,q)/(2*180);   % mean inFlow
        if ~((1-iC)*rateI_prev < rateI  &&  rateI < (1+iC)*rateI_prev)
           rateI = (rateI_prev + rateI)/2;
        end
        rateI_prev  = rateI;
        %}
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        
        rateS_m = S(1,q);         % mean speed
        rateS_m = rateS_m/(3.6*5.55555);   % convert km/h into NaSch-units
        if rateS_m > 5
            rateS_m = 5;
        elseif rateS_m < 2
            rateS_m = 2;
        end
    end
    INFLOWMATRIX(1,t) = rateI;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    rateS = ceil(rateS_m) - (rand < (ceil(rateS_m)-rateS_m));
    
    % update position X(1,1) left lane (inflow left)
    rate = rateI*.95;  % calculate inflow rate per second, /2 because we have 2 rows,*.95 because left lane
    
    if rand < rate && X(1,1) == -1
        X(1,1) = rateS;  % all cars enter with speed of rateS
        inflowCounter = inflowCounter + 1;
    end
    
    % update position X(2,1) right lane (inflow right)
    rate = rateI*1.05;  % calculate inflow rate per second, /2 because we have 2 rows,*1.05 because right lane
    
    if rand < rate && X(2,1) == -1
        X(2,1) = rateS;  % all cars enter with speed of rateS
        inflowCounter = inflowCounter + 1;
    end
    
    %% statistics
    % average speed
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
        if bV < 2  &&  bD > .5
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
    
    k = 1+mod(t-1,2400);
    congLength(1,k) = bC * bL;
    
    % allow only small changes
    if smallChanges
        if congLength(1,k) > congLength_prev
            congLength(1,k) = congLength_prev + smallChanges;
        elseif congLength(1,k) < congLength_prev
            congLength(1,k) = congLength_prev - smallChanges;
        else
            congLength(1,k) = congLength_prev;
        end
        congLength_prev = congLength(1,k);
    end
    
    % mesure congestion for 40min, store mean in congPlot
    if mod(t,2400) == 0
        congPlot(1,t/2400) = sum(congLength/conv) / 2400;
        % enable redlight, if congestion longer than 2km
        if congPlot(1,t/2400) > 2 && redLight_act
            redLight = 1;
        else
            redLight = 0;
        end
        currentCongestion = congPlot(1,t/2400);
    end
    
    % reset counters
    bC = 0;
    bE = 0;
    
    %% animation
    if isAnimated && (t > 10*3600 && t < 11*3600 || t > 15*3600)
        clf; hold on;
        xlim([N-100 N+1])
        ylim([-20 20])
        plot(N-100:cC+1, 0.5*ones(1,length(N-100:cC+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:N+1, -0.5*ones(1,length(N-100:N+1)), 'Color', [.75 .75 .75], 'LineWidth', 12)
        plot(N-100:cC+1, 0*(N-100:cC+1), '--', 'Color', [.95 .95 .95], 'LineWidth', .8)
        title([ 'Iterationsschritt: ' num2str(t), 'Zeit: ' T(1,q), '  Congestion: ' num2str(currentCongestion), '  Average Speed: ' num2str(vAverage), '  inFlow: ' num2str(rateI)])
        
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

% OUTFLOW -- count remaining cars on lanes
for i=1:2*N
    if X(i) ~= -1
        outflowCounter = outflowCounter + 1;
    end
end

% check if inflow is equal to outflow
if outflowCounter == inflowCounter
    disp (['inflow and outflow are equal to ' num2str(outflowCounter)]);
else
    disp 'error occured: inflow and outflow are different!!!'
end


% diagram of real congestion is already displayed by congPlot_r

% diagram of simulation congestion
figure()
bar(2/3:2/3:nIter/3600,congPlot)
title(' Simulation Congestion ')
xlabel('Anzahl Stunden -- gemessen alle 40min');
ylabel('Kilometer');
xlim([0 nIter/3600]);
if dataset == 2
    ylim([0 4]);
end
grid on;
figure()
bar(1:nIter, INFLOWMATRIX)
title(' inFlow ')
hold off;

% diagram of comparison model - reality
[X,Y,data] = congPlot_r(dataset);

figure()
hold on;
title(' Comparison Model - Reality ')
bar(2/3:2/3:nIter/3600,congPlot)
bar(X/3600,Y, .01, 'EdgeColor',[.8,.85,.9], 'FaceColor',[.8,.85,.9])

if mod(dataset,2)
    xlabel([datestr(data(1,:),'dd.mm.yyyy') ' - ' datestr(data(end,:),'dd.mm.yyyy')]);
else
    xlabel(datestr(data(1,:),'dd.mm.yyyy'));
end
ylabel('Kilometer');
if mod(dataset,2)
    xlim([0 48]);
else
    xlim([0 24]);
end
grid on;
hold off;

% error evaluation
error_rel = zeros(1,length(congPlot));
error_abs = zeros(1,length(congPlot));

for i=0:2400:nIter               % check every 2400s if real congestion data is available
    z = z+1;
    
    % accessing real and simulation congestion data
    if i == 0
        w = 1;                    % w is for Y (real congestion)
    elseif i == 2400
        u = 1;                    % prevent outbound
        z = 1;
    else
        u = u+1;                  % u is for congPlot (simulation congestion)
        w = i/96;
    end
    
    % relative error calculation per 40min
    if congPlot(1,u) == 0 && Y(1,w) == 0
        error_rel(1,z) = 0;
    elseif congPlot(1,u) > Y(1,w)
        error_rel(1,z) = congPlot(1,u) / Y(1,w) - 1;
    else                         % if congPlot(1,u) < Y(1,w)
        error_rel(1,z) = -(Y(1,w) / congPlot(1,u) - 1);
    end
    
    % absolute error calculation
    error_abs(1,z) = abs(congPlot(1,u) - Y(1,w));
end

% total error
error_tot = sum(error_abs);

% diagram of error
figure()
hold on;
title(' Absolute Error ')
bar(2/3:2/3:nIter/3600,error_abs,'r')

end

%% datasets
function [InFlow, Speed, Time] = Datasets(inSet)
Time = {'2014-07-18 00:00-00:03' '2014-07-18 00:03-00:06' '2014-07-18 00:06-00:09' '2014-07-18 00:09-00:12' '2014-07-18 00:12-00:15' '2014-07-18 00:15-00:18' '2014-07-18 00:18-00:21' '2014-07-18 00:21-00:24' '2014-07-18 00:24-00:27' '2014-07-18 00:27-00:30' '2014-07-18 00:30-00:33' '2014-07-18 00:33-00:36' '2014-07-18 00:36-00:39' '2014-07-18 00:39-00:42' '2014-07-18 00:42-00:45' '2014-07-18 00:45-00:48' '2014-07-18 00:48-00:51' '2014-07-18 00:51-00:54' '2014-07-18 00:54-00:57' '2014-07-18 00:57-01:00' '2014-07-18 01:00-01:03' '2014-07-18 01:03-01:06' '2014-07-18 01:06-01:09' '2014-07-18 01:09-01:12' '2014-07-18 01:12-01:15' '2014-07-18 01:15-01:18' '2014-07-18 01:18-01:21' '2014-07-18 01:21-01:24' '2014-07-18 01:24-01:27' '2014-07-18 01:27-01:30' '2014-07-18 01:30-01:33' '2014-07-18 01:33-01:36' '2014-07-18 01:36-01:39' '2014-07-18 01:39-01:42' '2014-07-18 01:42-01:45' '2014-07-18 01:45-01:48' '2014-07-18 01:48-01:51' '2014-07-18 01:51-01:54' '2014-07-18 01:54-01:57' '2014-07-18 01:57-02:00' '2014-07-18 02:00-02:03' '2014-07-18 02:03-02:06' '2014-07-18 02:06-02:09' '2014-07-18 02:09-02:12' '2014-07-18 02:12-02:15' '2014-07-18 02:15-02:18' '2014-07-18 02:18-02:21' '2014-07-18 02:21-02:24' '2014-07-18 02:24-02:27' '2014-07-18 02:27-02:30' '2014-07-18 02:30-02:33' '2014-07-18 02:33-02:36' '2014-07-18 02:36-02:39' '2014-07-18 02:39-02:42' '2014-07-18 02:42-02:45' '2014-07-18 02:45-02:48' '2014-07-18 02:48-02:51' '2014-07-18 02:51-02:54' '2014-07-18 02:54-02:57' '2014-07-18 02:57-03:00' '2014-07-18 03:00-03:03' '2014-07-18 03:03-03:06' '2014-07-18 03:06-03:09' '2014-07-18 03:09-03:12' '2014-07-18 03:12-03:15' '2014-07-18 03:15-03:18' '2014-07-18 03:18-03:21' '2014-07-18 03:21-03:24' '2014-07-18 03:24-03:27' '2014-07-18 03:27-03:30' '2014-07-18 03:30-03:33' '2014-07-18 03:33-03:36' '2014-07-18 03:36-03:39' '2014-07-18 03:39-03:42' '2014-07-18 03:42-03:45' '2014-07-18 03:45-03:48' '2014-07-18 03:48-03:51' '2014-07-18 03:51-03:54' '2014-07-18 03:54-03:57' '2014-07-18 03:57-04:00' '2014-07-18 04:00-04:03' '2014-07-18 04:03-04:06' '2014-07-18 04:06-04:09' '2014-07-18 04:09-04:12' '2014-07-18 04:12-04:15' '2014-07-18 04:15-04:18' '2014-07-18 04:18-04:21' '2014-07-18 04:21-04:24' '2014-07-18 04:24-04:27' '2014-07-18 04:27-04:30' '2014-07-18 04:30-04:33' '2014-07-18 04:33-04:36' '2014-07-18 04:36-04:39' '2014-07-18 04:39-04:42' '2014-07-18 04:42-04:45' '2014-07-18 04:45-04:48' '2014-07-18 04:48-04:51' '2014-07-18 04:51-04:54' '2014-07-18 04:54-04:57' '2014-07-18 04:57-05:00' '2014-07-18 05:00-05:03' '2014-07-18 05:03-05:06' '2014-07-18 05:06-05:09' '2014-07-18 05:09-05:12' '2014-07-18 05:12-05:15' '2014-07-18 05:15-05:18' '2014-07-18 05:18-05:21' '2014-07-18 05:21-05:24' '2014-07-18 05:24-05:27' '2014-07-18 05:27-05:30' '2014-07-18 05:30-05:33' '2014-07-18 05:33-05:36' '2014-07-18 05:36-05:39' '2014-07-18 05:39-05:42' '2014-07-18 05:42-05:45' '2014-07-18 05:45-05:48' '2014-07-18 05:48-05:51' '2014-07-18 05:51-05:54' '2014-07-18 05:54-05:57' '2014-07-18 05:57-06:00' '2014-07-18 06:00-06:03' '2014-07-18 06:03-06:06' '2014-07-18 06:06-06:09' '2014-07-18 06:09-06:12' '2014-07-18 06:12-06:15' '2014-07-18 06:15-06:18' '2014-07-18 06:18-06:21' '2014-07-18 06:21-06:24' '2014-07-18 06:24-06:27' '2014-07-18 06:27-06:30' '2014-07-18 06:30-06:33' '2014-07-18 06:33-06:36' '2014-07-18 06:36-06:39' '2014-07-18 06:39-06:42' '2014-07-18 06:42-06:45' '2014-07-18 06:45-06:48' '2014-07-18 06:48-06:51' '2014-07-18 06:51-06:54' '2014-07-18 06:54-06:57' '2014-07-18 06:57-07:00' '2014-07-18 07:00-07:03' '2014-07-18 07:03-07:06' '2014-07-18 07:06-07:09' '2014-07-18 07:09-07:12' '2014-07-18 07:12-07:15' '2014-07-18 07:15-07:18' '2014-07-18 07:18-07:21' '2014-07-18 07:21-07:24' '2014-07-18 07:24-07:27' '2014-07-18 07:27-07:30' '2014-07-18 07:30-07:33' '2014-07-18 07:33-07:36' '2014-07-18 07:36-07:39' '2014-07-18 07:39-07:42' '2014-07-18 07:42-07:45' '2014-07-18 07:45-07:48' '2014-07-18 07:48-07:51' '2014-07-18 07:51-07:54' '2014-07-18 07:54-07:57' '2014-07-18 07:57-08:00' '2014-07-18 08:00-08:03' '2014-07-18 08:03-08:06' '2014-07-18 08:06-08:09' '2014-07-18 08:09-08:12' '2014-07-18 08:12-08:15' '2014-07-18 08:15-08:18' '2014-07-18 08:18-08:21' '2014-07-18 08:21-08:24' '2014-07-18 08:24-08:27' '2014-07-18 08:27-08:30' '2014-07-18 08:30-08:33' '2014-07-18 08:33-08:36' '2014-07-18 08:36-08:39' '2014-07-18 08:39-08:42' '2014-07-18 08:42-08:45' '2014-07-18 08:45-08:48' '2014-07-18 08:48-08:51' '2014-07-18 08:51-08:54' '2014-07-18 08:54-08:57' '2014-07-18 08:57-09:00' '2014-07-18 09:00-09:03' '2014-07-18 09:03-09:06' '2014-07-18 09:06-09:09' '2014-07-18 09:09-09:12' '2014-07-18 09:12-09:15' '2014-07-18 09:15-09:18' '2014-07-18 09:18-09:21' '2014-07-18 09:21-09:24' '2014-07-18 09:24-09:27' '2014-07-18 09:27-09:30' '2014-07-18 09:30-09:33' '2014-07-18 09:33-09:36' '2014-07-18 09:36-09:39' '2014-07-18 09:39-09:42' '2014-07-18 09:42-09:45' '2014-07-18 09:45-09:48' '2014-07-18 09:48-09:51' '2014-07-18 09:51-09:54' '2014-07-18 09:54-09:57' '2014-07-18 09:57-10:00' '2014-07-18 10:00-10:03' '2014-07-18 10:03-10:06' '2014-07-18 10:06-10:09' '2014-07-18 10:09-10:12' '2014-07-18 10:12-10:15' '2014-07-18 10:15-10:18' '2014-07-18 10:18-10:21' '2014-07-18 10:21-10:24' '2014-07-18 10:24-10:27' '2014-07-18 10:27-10:30' '2014-07-18 10:30-10:33' '2014-07-18 10:33-10:36' '2014-07-18 10:36-10:39' '2014-07-18 10:39-10:42' '2014-07-18 10:42-10:45' '2014-07-18 10:45-10:48' '2014-07-18 10:48-10:51' '2014-07-18 10:51-10:54' '2014-07-18 10:54-10:57' '2014-07-18 10:57-11:00' '2014-07-18 11:00-11:03' '2014-07-18 11:03-11:06' '2014-07-18 11:06-11:09' '2014-07-18 11:09-11:12' '2014-07-18 11:12-11:15' '2014-07-18 11:15-11:18' '2014-07-18 11:18-11:21' '2014-07-18 11:21-11:24' '2014-07-18 11:24-11:27' '2014-07-18 11:27-11:30' '2014-07-18 11:30-11:33' '2014-07-18 11:33-11:36' '2014-07-18 11:36-11:39' '2014-07-18 11:39-11:42' '2014-07-18 11:42-11:45' '2014-07-18 11:45-11:48' '2014-07-18 11:48-11:51' '2014-07-18 11:51-11:54' '2014-07-18 11:54-11:57' '2014-07-18 11:57-12:00' '2014-07-18 12:00-12:03' '2014-07-18 12:03-12:06' '2014-07-18 12:06-12:09' '2014-07-18 12:09-12:12' '2014-07-18 12:12-12:15' '2014-07-18 12:15-12:18' '2014-07-18 12:18-12:21' '2014-07-18 12:21-12:24' '2014-07-18 12:24-12:27' '2014-07-18 12:27-12:30' '2014-07-18 12:30-12:33' '2014-07-18 12:33-12:36' '2014-07-18 12:36-12:39' '2014-07-18 12:39-12:42' '2014-07-18 12:42-12:45' '2014-07-18 12:45-12:48' '2014-07-18 12:48-12:51' '2014-07-18 12:51-12:54' '2014-07-18 12:54-12:57' '2014-07-18 12:57-13:00' '2014-07-18 13:00-13:03' '2014-07-18 13:03-13:06' '2014-07-18 13:06-13:09' '2014-07-18 13:09-13:12' '2014-07-18 13:12-13:15' '2014-07-18 13:15-13:18' '2014-07-18 13:18-13:21' '2014-07-18 13:21-13:24' '2014-07-18 13:24-13:27' '2014-07-18 13:27-13:30' '2014-07-18 13:30-13:33' '2014-07-18 13:33-13:36' '2014-07-18 13:36-13:39' '2014-07-18 13:39-13:42' '2014-07-18 13:42-13:45' '2014-07-18 13:45-13:48' '2014-07-18 13:48-13:51' '2014-07-18 13:51-13:54' '2014-07-18 13:54-13:57' '2014-07-18 13:57-14:00' '2014-07-18 14:00-14:03' '2014-07-18 14:03-14:06' '2014-07-18 14:06-14:09' '2014-07-18 14:09-14:12' '2014-07-18 14:12-14:15' '2014-07-18 14:15-14:18' '2014-07-18 14:18-14:21' '2014-07-18 14:21-14:24' '2014-07-18 14:24-14:27' '2014-07-18 14:27-14:30' '2014-07-18 14:30-14:33' '2014-07-18 14:33-14:36' '2014-07-18 14:36-14:39' '2014-07-18 14:39-14:42' '2014-07-18 14:42-14:45' '2014-07-18 14:45-14:48' '2014-07-18 14:48-14:51' '2014-07-18 14:51-14:54' '2014-07-18 14:54-14:57' '2014-07-18 14:57-15:00' '2014-07-18 15:00-15:03' '2014-07-18 15:03-15:06' '2014-07-18 15:06-15:09' '2014-07-18 15:09-15:12' '2014-07-18 15:12-15:15' '2014-07-18 15:15-15:18' '2014-07-18 15:18-15:21' '2014-07-18 15:21-15:24' '2014-07-18 15:24-15:27' '2014-07-18 15:27-15:30' '2014-07-18 15:30-15:33' '2014-07-18 15:33-15:36' '2014-07-18 15:36-15:39' '2014-07-18 15:39-15:42' '2014-07-18 15:42-15:45' '2014-07-18 15:45-15:48' '2014-07-18 15:48-15:51' '2014-07-18 15:51-15:54' '2014-07-18 15:54-15:57' '2014-07-18 15:57-16:00' '2014-07-18 16:00-16:03' '2014-07-18 16:03-16:06' '2014-07-18 16:06-16:09' '2014-07-18 16:09-16:12' '2014-07-18 16:12-16:15' '2014-07-18 16:15-16:18' '2014-07-18 16:18-16:21' '2014-07-18 16:21-16:24' '2014-07-18 16:24-16:27' '2014-07-18 16:27-16:30' '2014-07-18 16:30-16:33' '2014-07-18 16:33-16:36' '2014-07-18 16:36-16:39' '2014-07-18 16:39-16:42' '2014-07-18 16:42-16:45' '2014-07-18 16:45-16:48' '2014-07-18 16:48-16:51' '2014-07-18 16:51-16:54' '2014-07-18 16:54-16:57' '2014-07-18 16:57-17:00' '2014-07-18 17:00-17:03' '2014-07-18 17:03-17:06' '2014-07-18 17:06-17:09' '2014-07-18 17:09-17:12' '2014-07-18 17:12-17:15' '2014-07-18 17:15-17:18' '2014-07-18 17:18-17:21' '2014-07-18 17:21-17:24' '2014-07-18 17:24-17:27' '2014-07-18 17:27-17:30' '2014-07-18 17:30-17:33' '2014-07-18 17:33-17:36' '2014-07-18 17:36-17:39' '2014-07-18 17:39-17:42' '2014-07-18 17:42-17:45' '2014-07-18 17:45-17:48' '2014-07-18 17:48-17:51' '2014-07-18 17:51-17:54' '2014-07-18 17:54-17:57' '2014-07-18 17:57-18:00' '2014-07-18 18:00-18:03' '2014-07-18 18:03-18:06' '2014-07-18 18:06-18:09' '2014-07-18 18:09-18:12' '2014-07-18 18:12-18:15' '2014-07-18 18:15-18:18' '2014-07-18 18:18-18:21' '2014-07-18 18:21-18:24' '2014-07-18 18:24-18:27' '2014-07-18 18:27-18:30' '2014-07-18 18:30-18:33' '2014-07-18 18:33-18:36' '2014-07-18 18:36-18:39' '2014-07-18 18:39-18:42' '2014-07-18 18:42-18:45' '2014-07-18 18:45-18:48' '2014-07-18 18:48-18:51' '2014-07-18 18:51-18:54' '2014-07-18 18:54-18:57' '2014-07-18 18:57-19:00' '2014-07-18 19:00-19:03' '2014-07-18 19:03-19:06' '2014-07-18 19:06-19:09' '2014-07-18 19:09-19:12' '2014-07-18 19:12-19:15' '2014-07-18 19:15-19:18' '2014-07-18 19:18-19:21' '2014-07-18 19:21-19:24' '2014-07-18 19:24-19:27' '2014-07-18 19:27-19:30' '2014-07-18 19:30-19:33' '2014-07-18 19:33-19:36' '2014-07-18 19:36-19:39' '2014-07-18 19:39-19:42' '2014-07-18 19:42-19:45' '2014-07-18 19:45-19:48' '2014-07-18 19:48-19:51' '2014-07-18 19:51-19:54' '2014-07-18 19:54-19:57' '2014-07-18 19:57-20:00' '2014-07-18 20:00-20:03' '2014-07-18 20:03-20:06' '2014-07-18 20:06-20:09' '2014-07-18 20:09-20:12' '2014-07-18 20:12-20:15' '2014-07-18 20:15-20:18' '2014-07-18 20:18-20:21' '2014-07-18 20:21-20:24' '2014-07-18 20:24-20:27' '2014-07-18 20:27-20:30' '2014-07-18 20:30-20:33' '2014-07-18 20:33-20:36' '2014-07-18 20:36-20:39' '2014-07-18 20:39-20:42' '2014-07-18 20:42-20:45' '2014-07-18 20:45-20:48' '2014-07-18 20:48-20:51' '2014-07-18 20:51-20:54' '2014-07-18 20:54-20:57' '2014-07-18 20:57-21:00' '2014-07-18 21:00-21:03' '2014-07-18 21:03-21:06' '2014-07-18 21:06-21:09' '2014-07-18 21:09-21:12' '2014-07-18 21:12-21:15' '2014-07-18 21:15-21:18' '2014-07-18 21:18-21:21' '2014-07-18 21:21-21:24' '2014-07-18 21:24-21:27' '2014-07-18 21:27-21:30' '2014-07-18 21:30-21:33' '2014-07-18 21:33-21:36' '2014-07-18 21:36-21:39' '2014-07-18 21:39-21:42' '2014-07-18 21:42-21:45' '2014-07-18 21:45-21:48' '2014-07-18 21:48-21:51' '2014-07-18 21:51-21:54' '2014-07-18 21:54-21:57' '2014-07-18 21:57-22:00' '2014-07-18 22:00-22:03' '2014-07-18 22:03-22:06' '2014-07-18 22:06-22:09' '2014-07-18 22:09-22:12' '2014-07-18 22:12-22:15' '2014-07-18 22:15-22:18' '2014-07-18 22:18-22:21' '2014-07-18 22:21-22:24' '2014-07-18 22:24-22:27' '2014-07-18 22:27-22:30' '2014-07-18 22:30-22:33' '2014-07-18 22:33-22:36' '2014-07-18 22:36-22:39' '2014-07-18 22:39-22:42' '2014-07-18 22:42-22:45' '2014-07-18 22:45-22:48' '2014-07-18 22:48-22:51' '2014-07-18 22:51-22:54' '2014-07-18 22:54-22:57' '2014-07-18 22:57-23:00' '2014-07-18 23:00-23:03' '2014-07-18 23:03-23:06' '2014-07-18 23:06-23:09' '2014-07-18 23:09-23:12' '2014-07-18 23:12-23:15' '2014-07-18 23:15-23:18' '2014-07-18 23:18-23:21' '2014-07-18 23:21-23:24' '2014-07-18 23:24-23:27' '2014-07-18 23:27-23:30' '2014-07-18 23:30-23:33' '2014-07-18 23:33-23:36' '2014-07-18 23:36-23:39' '2014-07-18 23:39-23:42' '2014-07-18 23:42-23:45' '2014-07-18 23:45-23:48' '2014-07-18 23:48-23:51' '2014-07-18 23:51-23:54' '2014-07-18 23:54-23:57' '2014-07-18 23:57-00:00' '2014-07-19 00:00-00:03' '2014-07-19 00:03-00:06' '2014-07-19 00:06-00:09' '2014-07-19 00:09-00:12' '2014-07-19 00:12-00:15' '2014-07-19 00:15-00:18' '2014-07-19 00:18-00:21' '2014-07-19 00:21-00:24' '2014-07-19 00:24-00:27' '2014-07-19 00:27-00:30' '2014-07-19 00:30-00:33' '2014-07-19 00:33-00:36' '2014-07-19 00:36-00:39' '2014-07-19 00:39-00:42' '2014-07-19 00:42-00:45' '2014-07-19 00:45-00:48' '2014-07-19 00:48-00:51' '2014-07-19 00:51-00:54' '2014-07-19 00:54-00:57' '2014-07-19 00:57-01:00' '2014-07-19 01:00-01:03' '2014-07-19 01:03-01:06' '2014-07-19 01:06-01:09' '2014-07-19 01:09-01:12' '2014-07-19 01:12-01:15' '2014-07-19 01:15-01:18' '2014-07-19 01:18-01:21' '2014-07-19 01:21-01:24' '2014-07-19 01:24-01:27' '2014-07-19 01:27-01:30' '2014-07-19 01:30-01:33' '2014-07-19 01:33-01:36' '2014-07-19 01:36-01:39' '2014-07-19 01:39-01:42' '2014-07-19 01:42-01:45' '2014-07-19 01:45-01:48' '2014-07-19 01:48-01:51' '2014-07-19 01:51-01:54' '2014-07-19 01:54-01:57' '2014-07-19 01:57-02:00' '2014-07-19 02:00-02:03' '2014-07-19 02:03-02:06' '2014-07-19 02:06-02:09' '2014-07-19 02:09-02:12' '2014-07-19 02:12-02:15' '2014-07-19 02:15-02:18' '2014-07-19 02:18-02:21' '2014-07-19 02:21-02:24' '2014-07-19 02:24-02:27' '2014-07-19 02:27-02:30' '2014-07-19 02:30-02:33' '2014-07-19 02:33-02:36' '2014-07-19 02:36-02:39' '2014-07-19 02:39-02:42' '2014-07-19 02:42-02:45' '2014-07-19 02:45-02:48' '2014-07-19 02:48-02:51' '2014-07-19 02:51-02:54' '2014-07-19 02:54-02:57' '2014-07-19 02:57-03:00' '2014-07-19 03:00-03:03' '2014-07-19 03:03-03:06' '2014-07-19 03:06-03:09' '2014-07-19 03:09-03:12' '2014-07-19 03:12-03:15' '2014-07-19 03:15-03:18' '2014-07-19 03:18-03:21' '2014-07-19 03:21-03:24' '2014-07-19 03:24-03:27' '2014-07-19 03:27-03:30' '2014-07-19 03:30-03:33' '2014-07-19 03:33-03:36' '2014-07-19 03:36-03:39' '2014-07-19 03:39-03:42' '2014-07-19 03:42-03:45' '2014-07-19 03:45-03:48' '2014-07-19 03:48-03:51' '2014-07-19 03:51-03:54' '2014-07-19 03:54-03:57' '2014-07-19 03:57-04:00' '2014-07-19 04:00-04:03' '2014-07-19 04:03-04:06' '2014-07-19 04:06-04:09' '2014-07-19 04:09-04:12' '2014-07-19 04:12-04:15' '2014-07-19 04:15-04:18' '2014-07-19 04:18-04:21' '2014-07-19 04:21-04:24' '2014-07-19 04:24-04:27' '2014-07-19 04:27-04:30' '2014-07-19 04:30-04:33' '2014-07-19 04:33-04:36' '2014-07-19 04:36-04:39' '2014-07-19 04:39-04:42' '2014-07-19 04:42-04:45' '2014-07-19 04:45-04:48' '2014-07-19 04:48-04:51' '2014-07-19 04:51-04:54' '2014-07-19 04:54-04:57' '2014-07-19 04:57-05:00' '2014-07-19 05:00-05:03' '2014-07-19 05:03-05:06' '2014-07-19 05:06-05:09' '2014-07-19 05:09-05:12' '2014-07-19 05:12-05:15' '2014-07-19 05:15-05:18' '2014-07-19 05:18-05:21' '2014-07-19 05:21-05:24' '2014-07-19 05:24-05:27' '2014-07-19 05:27-05:30' '2014-07-19 05:30-05:33' '2014-07-19 05:33-05:36' '2014-07-19 05:36-05:39' '2014-07-19 05:39-05:42' '2014-07-19 05:42-05:45' '2014-07-19 05:45-05:48' '2014-07-19 05:48-05:51' '2014-07-19 05:51-05:54' '2014-07-19 05:54-05:57' '2014-07-19 05:57-06:00' '2014-07-19 06:00-06:03' '2014-07-19 06:03-06:06' '2014-07-19 06:06-06:09' '2014-07-19 06:09-06:12' '2014-07-19 06:12-06:15' '2014-07-19 06:15-06:18' '2014-07-19 06:18-06:21' '2014-07-19 06:21-06:24' '2014-07-19 06:24-06:27' '2014-07-19 06:27-06:30' '2014-07-19 06:30-06:33' '2014-07-19 06:33-06:36' '2014-07-19 06:36-06:39' '2014-07-19 06:39-06:42' '2014-07-19 06:42-06:45' '2014-07-19 06:45-06:48' '2014-07-19 06:48-06:51' '2014-07-19 06:51-06:54' '2014-07-19 06:54-06:57' '2014-07-19 06:57-07:00' '2014-07-19 07:00-07:03' '2014-07-19 07:03-07:06' '2014-07-19 07:06-07:09' '2014-07-19 07:09-07:12' '2014-07-19 07:12-07:15' '2014-07-19 07:15-07:18' '2014-07-19 07:18-07:21' '2014-07-19 07:21-07:24' '2014-07-19 07:24-07:27' '2014-07-19 07:27-07:30' '2014-07-19 07:30-07:33' '2014-07-19 07:33-07:36' '2014-07-19 07:36-07:39' '2014-07-19 07:39-07:42' '2014-07-19 07:42-07:45' '2014-07-19 07:45-07:48' '2014-07-19 07:48-07:51' '2014-07-19 07:51-07:54' '2014-07-19 07:54-07:57' '2014-07-19 07:57-08:00' '2014-07-19 08:00-08:03' '2014-07-19 08:03-08:06' '2014-07-19 08:06-08:09' '2014-07-19 08:09-08:12' '2014-07-19 08:12-08:15' '2014-07-19 08:15-08:18' '2014-07-19 08:18-08:21' '2014-07-19 08:21-08:24' '2014-07-19 08:24-08:27' '2014-07-19 08:27-08:30' '2014-07-19 08:30-08:33' '2014-07-19 08:33-08:36' '2014-07-19 08:36-08:39' '2014-07-19 08:39-08:42' '2014-07-19 08:42-08:45' '2014-07-19 08:45-08:48' '2014-07-19 08:48-08:51' '2014-07-19 08:51-08:54' '2014-07-19 08:54-08:57' '2014-07-19 08:57-09:00' '2014-07-19 09:00-09:03' '2014-07-19 09:03-09:06' '2014-07-19 09:06-09:09' '2014-07-19 09:09-09:12' '2014-07-19 09:12-09:15' '2014-07-19 09:15-09:18' '2014-07-19 09:18-09:21' '2014-07-19 09:21-09:24' '2014-07-19 09:24-09:27' '2014-07-19 09:27-09:30' '2014-07-19 09:30-09:33' '2014-07-19 09:33-09:36' '2014-07-19 09:36-09:39' '2014-07-19 09:39-09:42' '2014-07-19 09:42-09:45' '2014-07-19 09:45-09:48' '2014-07-19 09:48-09:51' '2014-07-19 09:51-09:54' '2014-07-19 09:54-09:57' '2014-07-19 09:57-10:00' '2014-07-19 10:00-10:03' '2014-07-19 10:03-10:06' '2014-07-19 10:06-10:09' '2014-07-19 10:09-10:12' '2014-07-19 10:12-10:15' '2014-07-19 10:15-10:18' '2014-07-19 10:18-10:21' '2014-07-19 10:21-10:24' '2014-07-19 10:24-10:27' '2014-07-19 10:27-10:30' '2014-07-19 10:30-10:33' '2014-07-19 10:33-10:36' '2014-07-19 10:36-10:39' '2014-07-19 10:39-10:42' '2014-07-19 10:42-10:45' '2014-07-19 10:45-10:48' '2014-07-19 10:48-10:51' '2014-07-19 10:51-10:54' '2014-07-19 10:54-10:57' '2014-07-19 10:57-11:00' '2014-07-19 11:00-11:03' '2014-07-19 11:03-11:06' '2014-07-19 11:06-11:09' '2014-07-19 11:09-11:12' '2014-07-19 11:12-11:15' '2014-07-19 11:15-11:18' '2014-07-19 11:18-11:21' '2014-07-19 11:21-11:24' '2014-07-19 11:24-11:27' '2014-07-19 11:27-11:30' '2014-07-19 11:30-11:33' '2014-07-19 11:33-11:36' '2014-07-19 11:36-11:39' '2014-07-19 11:39-11:42' '2014-07-19 11:42-11:45' '2014-07-19 11:45-11:48' '2014-07-19 11:48-11:51' '2014-07-19 11:51-11:54' '2014-07-19 11:54-11:57' '2014-07-19 11:57-12:00' '2014-07-19 12:00-12:03' '2014-07-19 12:03-12:06' '2014-07-19 12:06-12:09' '2014-07-19 12:09-12:12' '2014-07-19 12:12-12:15' '2014-07-19 12:15-12:18' '2014-07-19 12:18-12:21' '2014-07-19 12:21-12:24' '2014-07-19 12:24-12:27' '2014-07-19 12:27-12:30' '2014-07-19 12:30-12:33' '2014-07-19 12:33-12:36' '2014-07-19 12:36-12:39' '2014-07-19 12:39-12:42' '2014-07-19 12:42-12:45' '2014-07-19 12:45-12:48' '2014-07-19 12:48-12:51' '2014-07-19 12:51-12:54' '2014-07-19 12:54-12:57' '2014-07-19 12:57-13:00' '2014-07-19 13:00-13:03' '2014-07-19 13:03-13:06' '2014-07-19 13:06-13:09' '2014-07-19 13:09-13:12' '2014-07-19 13:12-13:15' '2014-07-19 13:15-13:18' '2014-07-19 13:18-13:21' '2014-07-19 13:21-13:24' '2014-07-19 13:24-13:27' '2014-07-19 13:27-13:30' '2014-07-19 13:30-13:33' '2014-07-19 13:33-13:36' '2014-07-19 13:36-13:39' '2014-07-19 13:39-13:42' '2014-07-19 13:42-13:45' '2014-07-19 13:45-13:48' '2014-07-19 13:48-13:51' '2014-07-19 13:51-13:54' '2014-07-19 13:54-13:57' '2014-07-19 13:57-14:00' '2014-07-19 14:00-14:03' '2014-07-19 14:03-14:06' '2014-07-19 14:06-14:09' '2014-07-19 14:09-14:12' '2014-07-19 14:12-14:15' '2014-07-19 14:15-14:18' '2014-07-19 14:18-14:21' '2014-07-19 14:21-14:24' '2014-07-19 14:24-14:27' '2014-07-19 14:27-14:30' '2014-07-19 14:30-14:33' '2014-07-19 14:33-14:36' '2014-07-19 14:36-14:39' '2014-07-19 14:39-14:42' '2014-07-19 14:42-14:45' '2014-07-19 14:45-14:48' '2014-07-19 14:48-14:51' '2014-07-19 14:51-14:54' '2014-07-19 14:54-14:57' '2014-07-19 14:57-15:00' '2014-07-19 15:00-15:03' '2014-07-19 15:03-15:06' '2014-07-19 15:06-15:09' '2014-07-19 15:09-15:12' '2014-07-19 15:12-15:15' '2014-07-19 15:15-15:18' '2014-07-19 15:18-15:21' '2014-07-19 15:21-15:24' '2014-07-19 15:24-15:27' '2014-07-19 15:27-15:30' '2014-07-19 15:30-15:33' '2014-07-19 15:33-15:36' '2014-07-19 15:36-15:39' '2014-07-19 15:39-15:42' '2014-07-19 15:42-15:45' '2014-07-19 15:45-15:48' '2014-07-19 15:48-15:51' '2014-07-19 15:51-15:54' '2014-07-19 15:54-15:57' '2014-07-19 15:57-16:00' '2014-07-19 16:00-16:03' '2014-07-19 16:03-16:06' '2014-07-19 16:06-16:09' '2014-07-19 16:09-16:12' '2014-07-19 16:12-16:15' '2014-07-19 16:15-16:18' '2014-07-19 16:18-16:21' '2014-07-19 16:21-16:24' '2014-07-19 16:24-16:27' '2014-07-19 16:27-16:30' '2014-07-19 16:30-16:33' '2014-07-19 16:33-16:36' '2014-07-19 16:36-16:39' '2014-07-19 16:39-16:42' '2014-07-19 16:42-16:45' '2014-07-19 16:45-16:48' '2014-07-19 16:48-16:51' '2014-07-19 16:51-16:54' '2014-07-19 16:54-16:57' '2014-07-19 16:57-17:00' '2014-07-19 17:00-17:03' '2014-07-19 17:03-17:06' '2014-07-19 17:06-17:09' '2014-07-19 17:09-17:12' '2014-07-19 17:12-17:15' '2014-07-19 17:15-17:18' '2014-07-19 17:18-17:21' '2014-07-19 17:21-17:24' '2014-07-19 17:24-17:27' '2014-07-19 17:27-17:30' '2014-07-19 17:30-17:33' '2014-07-19 17:33-17:36' '2014-07-19 17:36-17:39' '2014-07-19 17:39-17:42' '2014-07-19 17:42-17:45' '2014-07-19 17:45-17:48' '2014-07-19 17:48-17:51' '2014-07-19 17:51-17:54' '2014-07-19 17:54-17:57' '2014-07-19 17:57-18:00' '2014-07-19 18:00-18:03' '2014-07-19 18:03-18:06' '2014-07-19 18:06-18:09' '2014-07-19 18:09-18:12' '2014-07-19 18:12-18:15' '2014-07-19 18:15-18:18' '2014-07-19 18:18-18:21' '2014-07-19 18:21-18:24' '2014-07-19 18:24-18:27' '2014-07-19 18:27-18:30' '2014-07-19 18:30-18:33' '2014-07-19 18:33-18:36' '2014-07-19 18:36-18:39' '2014-07-19 18:39-18:42' '2014-07-19 18:42-18:45' '2014-07-19 18:45-18:48' '2014-07-19 18:48-18:51' '2014-07-19 18:51-18:54' '2014-07-19 18:54-18:57' '2014-07-19 18:57-19:00' '2014-07-19 19:00-19:03' '2014-07-19 19:03-19:06' '2014-07-19 19:06-19:09' '2014-07-19 19:09-19:12' '2014-07-19 19:12-19:15' '2014-07-19 19:15-19:18' '2014-07-19 19:18-19:21' '2014-07-19 19:21-19:24' '2014-07-19 19:24-19:27' '2014-07-19 19:27-19:30' '2014-07-19 19:30-19:33' '2014-07-19 19:33-19:36' '2014-07-19 19:36-19:39' '2014-07-19 19:39-19:42' '2014-07-19 19:42-19:45' '2014-07-19 19:45-19:48' '2014-07-19 19:48-19:51' '2014-07-19 19:51-19:54' '2014-07-19 19:54-19:57' '2014-07-19 19:57-20:00' '2014-07-19 20:00-20:03' '2014-07-19 20:03-20:06' '2014-07-19 20:06-20:09' '2014-07-19 20:09-20:12' '2014-07-19 20:12-20:15' '2014-07-19 20:15-20:18' '2014-07-19 20:18-20:21' '2014-07-19 20:21-20:24' '2014-07-19 20:24-20:27' '2014-07-19 20:27-20:30' '2014-07-19 20:30-20:33' '2014-07-19 20:33-20:36' '2014-07-19 20:36-20:39' '2014-07-19 20:39-20:42' '2014-07-19 20:42-20:45' '2014-07-19 20:45-20:48' '2014-07-19 20:48-20:51' '2014-07-19 20:51-20:54' '2014-07-19 20:54-20:57' '2014-07-19 20:57-21:00' '2014-07-19 21:00-21:03' '2014-07-19 21:03-21:06' '2014-07-19 21:06-21:09' '2014-07-19 21:09-21:12' '2014-07-19 21:12-21:15' '2014-07-19 21:15-21:18' '2014-07-19 21:18-21:21' '2014-07-19 21:21-21:24' '2014-07-19 21:24-21:27' '2014-07-19 21:27-21:30' '2014-07-19 21:30-21:33' '2014-07-19 21:33-21:36' '2014-07-19 21:36-21:39' '2014-07-19 21:39-21:42' '2014-07-19 21:42-21:45' '2014-07-19 21:45-21:48' '2014-07-19 21:48-21:51' '2014-07-19 21:51-21:54' '2014-07-19 21:54-21:57' '2014-07-19 21:57-22:00' '2014-07-19 22:00-22:03' '2014-07-19 22:03-22:06' '2014-07-19 22:06-22:09' '2014-07-19 22:09-22:12' '2014-07-19 22:12-22:15' '2014-07-19 22:15-22:18' '2014-07-19 22:18-22:21' '2014-07-19 22:21-22:24' '2014-07-19 22:24-22:27' '2014-07-19 22:27-22:30' '2014-07-19 22:30-22:33' '2014-07-19 22:33-22:36' '2014-07-19 22:36-22:39' '2014-07-19 22:39-22:42' '2014-07-19 22:42-22:45' '2014-07-19 22:45-22:48' '2014-07-19 22:48-22:51' '2014-07-19 22:51-22:54' '2014-07-19 22:54-22:57' '2014-07-19 22:57-23:00' '2014-07-19 23:00-23:03' '2014-07-19 23:03-23:06' '2014-07-19 23:06-23:09' '2014-07-19 23:09-23:12' '2014-07-19 23:12-23:15' '2014-07-19 23:15-23:18' '2014-07-19 23:18-23:21' '2014-07-19 23:21-23:24' '2014-07-19 23:24-23:27' '2014-07-19 23:27-23:30' '2014-07-19 23:30-23:33' '2014-07-19 23:33-23:36' '2014-07-19 23:36-23:39' '2014-07-19 23:39-23:42' '2014-07-19 23:42-23:45' '2014-07-19 23:45-23:48' '2014-07-19 23:48-23:51' '2014-07-19 23:51-23:54' '2014-07-19 23:54-23:57' '2014-07-19 23:57-00:00'};
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