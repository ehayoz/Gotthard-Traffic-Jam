function [density, flow] = NaSch_cars(moveProb, inFlow)

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

% define road (1 = car, 0 = no car)
X = rand(1,N) < inFlow;

% define velocities:
V = zeros(1,N);

% set statistical variables
movedCars = 0;
density = 0;

% main loop, iterating the time variable, t
for t = 1:nIter
    
    % save current road
    Xold = X;
    
    % acceleration (NaSch -- RULE 1) ================
    for i = 1:N
        if X(i) && V(i) < vmax
           V(i) = V(i) + 1;
        end
    end

    % slowing down (NaSch -- RULE 2) ================
    for i = 1:N
        if X(i) && i+V(i) <= N
           for j = 1:V(i)
               if X(i+j)
                  V(i) = j-1;
                  break
               end
           end
        end
    end
        
    % randomization (NaSch -- RULE 3) ===============
    for i = 1:N
        if V(i) > 0
           V(i) = V(i) - (rand > moveProb);
        end
    end

    % car motion (NaSch -- RULE 4) ==================

    % update positions X(1..N)
    for i = 1:N
        if X(i) && ( V(i) + i <= N )
           X(i+V(i)) = 1;
           % keep track of how many cars are moved forwards. 
           % Needed for calculating the flow later on.
           movedCars = movedCars + 1; 
        end
    end
    
    % remove cars from old place using XOR
    X = xor(Xold, X);
    
    % add non-moving cars (they were removed by XOR)
    for i = 1:N
        if Xold(i) && (V(i) == 0)
           X(i) = 1;
        end
    end
    
    % update velocities
    for i = 1:N
        if Xold(i) && ( V(i) + i <= N )
           v = V(i);
           V(i) = 0;
           V(i+v) = v;
        end
    end
            
            
    % update position X(1) (inflow)
    if rand < inFlow
        X(1) = 1;
        % for new cars: v=vmax
        V(1) = vmax;
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
        if ( X(i) )
           draw_car(i, 0, 0.8, 0.2);
        end
    end
    pause(.08)
end

% rescale statistical vaiables before returing them
density = density/nIter;
flow = movedCars/(N*nIter);
