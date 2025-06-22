close all

Energy_convert_sim = 10^3; %kWh to Wh
%Energy_convert_sim = 1; %kWh to kWh

% Variables
Variability = true; % true or false
Time_step = 1; % minutes
numRuns = 100; % Number of Variable updates
numSimulations = 15; % Number of parallel simulations

% Demand
Energy_year = 475*10^3; % (kWh for year)
Power_day = Energy_year/365; % (kWh for day) % (*7/5)
Power_average = Power_day/24; % (kWh for hour) % (22-7.5)
Energy_average = Power_average/60*Time_step; %(kWh for timestep)

% Fluidized bed
Energy_Reduc = 583.8; % kWh (5 hours)
m_Reduc = 2477.16; % kg (5 hours)
Power_Reduc = Energy_Reduc/(5*60)*Time_step ...
    *Energy_convert_sim; % (k)Wh/timestep
m_dot_Reduc = m_Reduc/(5*60)*Time_step; % kg/timestep

% % Electrolisys
% Energy_Reduc = 8269.355; % kWh (14 hours)
% m_Reduc = 1768.767; % kg (14 hours)
% Power_Reduc = Energy_Reduc/(14*60)*Time_step ...
%     *Energy_convert_sim; % (k)Wh/timestep
% m_dot_Reduc = m_Reduc/(14*60)*Time_step; % kg/timestep

% Combustion
EnergyMass_Combust = 1.35; % kWh/kg 
m_dot_Combust = 44.53*10^-3; % kg/s
m_dot_CombustMax = m_dot_Combust*60*Time_step; % kg/timestep
Energy_CombustMax = EnergyMass_Combust*m_dot_CombustMax ...
    *Energy_convert_sim; % (k)Wh/timestep

Efficiency_Ideal = Energy_CombustMax/Power_Reduc;

% Preallocate array for Simulink.SimulationInput objects
modelName = "Simulation"; % use your actual model name here
simIn = repmat(Simulink.SimulationInput(modelName), 1, numSimulations);
Overshoot_factor = 1.5;
demand_weight = 2;
E_pot_weight = 1;
Solar_weight = 0.05;
prev_cost = inf;

% adjusted variables start
Solar_panels_new = 10000;
BatterySize_new = 10; % kWh
StorageSize_new = 4000000; % kg

% PI tracking Initialization 
SolarPanel = [];
Efficiency = [];
E_Bat_unused = [];
E_Bruto_neg = [];
E_Pot = [];
Cost = [];

for ii = 1:numRuns

    % adjusted variables start
    Solar_panels = Solar_panels_new;
    BatterySize = BatterySize_new*Energy_convert_sim; % kWh
    StorageSize = StorageSize_new; % k
    
    for jj = 1:numSimulations % Test cycles
    
        for days = 1:365
            % Seasons
            if days <= 92
                season = "Spring";
            elseif days <= 184 % 92
                season = "Summer";
            elseif days <= 275 % 91
                season = "Fall"; 
            else % 90
                season = "Winter"; 
            end
        
            % Solar energy
            [Time_array, Energy_array] = Solar_generation_V2(Solar_panels, season, Variability, Time_step/60);
           
            % Neuron demand
            Day_indicator = mod(days,7); % 0 for sunday and 6 for saturday
            Energy_Neuron = [];
            for ii = 1:length(Time_array)
                Time = Time_array(ii);
                if Time >= 7.5 && Time <= 22 && Day_indicator ~= 0 && Day_indicator ~= 6
                    Energy_Neuron = [Energy_Neuron, Energy_average];
                else
                    Energy_Neuron = [Energy_Neuron, 0];
                end
            end
        
            % Postprocessing
            if days == 1
                Timer = Time_array;
                Solar_energy = Energy_array;
                Energy_Demand = Energy_Neuron;
            else
                Timer = [Timer, Time_array+24*(days-1)];
                Solar_energy = [Solar_energy, Energy_array];
                Energy_Demand = [Energy_Demand, Energy_Neuron];
            end
        end
    
        % Simulink Variables
        tstop = Timer(end);
        simIn(jj)  = simIn(jj) .setVariable("tstop", tstop);
    
        Solar_ts = timeseries(Solar_energy*Energy_convert_sim,Timer); % (k)Wh/timestep
        Demand_ts = timeseries(Energy_Demand*Energy_convert_sim,Timer); % (k)Wh/timestep
    
        % Set variable in simulation input
        simIn(jj) = simIn(jj).setVariable("Solar_ts", Solar_ts);
    end
    
    % Run simulations in parallel
    simOut = parsim(simIn, ...
        'ShowProgress', false, ...
        'TransferBaseWorkspaceVariables', 'on');
    
    for kk = 1:numSimulations
        Max_E_Bat_un(kk) = max(simOut(kk).get('E_Bat_un').data);
        E_Reduc_sum(kk) = sum(squeeze(simOut(kk).get('E_Reduc').data));
        E_Combust_sum(kk) = sum(squeeze(simOut(kk).get('E_Combust').data));
        E_Bruto_sum_neg(kk) = sum(min(squeeze(simOut(kk).get('E_Bruto').data),0));
    end
    
    Efficiency_Test = mean(E_Combust_sum)/mean(E_Reduc_sum);
    E_Bruto_mean_neg = mean(E_Bruto_sum_neg);
    Max_E_Bat_un_mean = mean(Max_E_Bat_un);
    E_over = mean(E_Reduc_sum)-mean(E_Combust_sum);

    % PI tracking
    SolarPanel = [SolarPanel, Solar_panels_new];
    Efficiency = [Efficiency, Efficiency_Test];
    E_Bat_unused = [E_Bat_unused, Max_E_Bat_un_mean];
    E_Bruto_neg = [E_Bruto_neg, E_Bruto_mean_neg];
    E_Pot = [E_Pot, E_over];

    % update Variables
    BatterySize_new = BatterySize_new + mean(Max_E_Bat_un);

    % Cost function for Solar panels
    current_cost = abs(E_pot_weight*E_over/Energy_convert_sim) + abs(demand_weight*E_Bruto_mean_neg/Energy_convert_sim);

    if current_cost*Overshoot_factor > prev_cost
        Solar_weight = Solar_weight*0.95;
    end

    % Gradient-like update 
    if abs(E_pot_weight*E_over) > abs(demand_weight*E_Bruto_mean_neg)
        Solar_panels_new = round(Solar_panels_new - Solar_weight * current_cost);
    else
        Solar_panels_new = round(Solar_panels_new + Solar_weight * current_cost);
    end

    Cost = [Cost, current_cost];
    prev_cost = current_cost;
    
    fprintf('Trial %d\n', ii);
end

figure;
subplot(2,1,1);
plot(SolarPanel);
title('Solar panel amount');
xlabel('Trial');
ylabel('amount');
grid on;

subplot(2,1,2);
plot(Cost);
title('Cost');
xlabel('Trial');
ylabel('Value');
grid on;

figure;
subplot(2,1,1);
hold on
plot(E_Pot);
hold on
plot(E_Bruto_neg)
hold off
title('E_{KPI}');
xlabel('Trial');
ylabel('Value (W)');
legend({'E_{pot}', 'E_{unmet}'}, 'Location', 'best');
grid on;

subplot(2,1,2);
hold on
plot(Efficiency);
hold on
yline(Efficiency_Ideal)
hold off
title('Efficiency');
xlabel('Trial');
ylabel('%');
legend({'Simulation', 'Ideal'}, 'Location', 'best');
grid on;