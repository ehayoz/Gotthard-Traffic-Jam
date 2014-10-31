function [ output_args ] = NaSch_2cars(v1, v2, p, m)
% v2 eingeben hat hier keinen Einfluss da v2 zu Demozwecken zuf�llig erzeugt
% wird
% Auto1 folgt dem Auto2

% Anfangsgeschwindigkeit von Auto1 (v1) und Auto2 (v2) eingeben; 0 <= v <=5, v e N
% Tr�delfaktor angeben, 0 <= p <= 1
% Anz. Matrix-Zeilen angeben, m > 100

X = sparse(m,1);       % m x 1 Matrix erstellen

% Anfangsbedingungen
d1prev = 1;     % Startwert Auto1 (d1prev >= 1)
d2prev = 5;     % Startwert Auto2
d1 = 0;
d2 = 6;


% Loop �ber i Runden
for i = 1:100
pause (.1)
spy(X)          % Matrix darstellen
title(num2str(i))
drawnow         % Matrix auf Bildschirm updaten


% Geschwindigkeit Auto1 beeinflussen (es folgt dem Auto2)
if v1<5             % V1 UM 1 ERH�HEN, 1. REGEL ===============================
    v1 = v1+1;
end

d = d2-d1;          % KOLLISIONSFREIHEIT, 2. REGEL ============================
if v1>d
    v1 = d;
end

v1 = v1 - (rand < p);    % TR�DELN, 3. REGEL ==================================

if v1<0             % ALLE BEWEGUNGEN VORW�RTS, 4. REGEL ======================
    v1=0;
end

% ==> v1 bestimmt

v2 = random('unid',5);  % v2 zuf�llig erzeugen

% ==> v2 bestimmt


% Auto1 updaten
s1 = v1;               % v1 in s1 "umwandeln"
d1 = d1prev + s1;      % Gefahrene Distanz d. Autos in der i-ten Runde

X(d1,1) = 1;           % Distanz in Matrixposition umwandeln und Auto anzeigen (1)
if i>1
    X(d1prev,1) = 0;   % Zelle wo Auto vorher war freigeben
end
d1prev = d1;

% Auto2 updaten
s2 = v2;               % v2 in s2 "umwandeln"
d2 = d2prev + s2;      % Gefahrene Distanz d. Autos in der i-ten Runde

X(d2,1) = 1;           % Distanz in Matrixposition umwandeln und Auto anzeigen (1)
if i>1
    X(d2prev,1) = 0;   % Zelle wo Auto vorher war freigeben
end
d2prev = d2;



end
