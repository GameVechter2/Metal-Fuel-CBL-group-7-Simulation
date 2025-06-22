close all

Energy_convert_sim = 10^3; %kWh to Wh
%Energy_convert_sim = 1; %kWh to kWh

% Variables
Solar_panels = 5000;
Variability = true; % true or false
Time_step = 1; % minutes

Energy_year = 475*10^3; % (kWh for year)
Power_day = Energy_year/365; % (kWh for day) % (*7/5)
Power_average = Power_day/24; % (kWh for hour) % (22-7.5)
Energy_average = Power_average/60*Time_step; %(kWh for timestep)


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

figure
plot(Timer, Solar_energy, 'LineWidth', 2)
hold on
plot(Timer, Energy_Demand, 'LineWidth', 2)
%title('Energy Generated during each season (Gaussian)');
xlabel('Time (minutes)');
ylabel("Energy Generated (kWh)");
grid on;
hold off

Solar_tot = sum(Solar_energy) %(kWh)
Demand_tot = sum(Energy_Demand) %(kWh)

% Simulink Variables
tstop = Timer(end);
deltat = Time_step;

% Fluidized bed
Energy_Reduc = 530; % kWh (5 hours)
m_Reduc = 1.1*10^3; % kg/h (5 hours)
Power_Reduc = Energy_Reduc/(5*60)*deltat ...
    *Energy_convert_sim; % (k)Wh/timestep
m_dot_Reduc = m_Reduc/(5*60)*deltat; % kg/timestep

% Electrolisys
%Energy_Reduc = 8269.355; % kWh (14 hours)
%m_Reduc = ?; % kg/h (14 hours)

% Combustion
EnergyMass_Combust = 0.8524; % kWh/kg 
m_dot_Combust = 327.5*10^-3; % kg/s
m_dot_CombustMax = m_dot_Combust*60*deltat; % kg/timestep
Energy_CombustMax = EnergyMass_Combust*m_dot_CombustMax ...
    *Energy_convert_sim; % (k)Wh/timestep

BatterySize = 10*Energy_convert_sim; % kWh
StorageSize = 4000000; % kg

Solar_ts = timeseries(Solar_energy*Energy_convert_sim,Timer); % (k)Wh/timestep
Demand_ts = timeseries(Energy_Demand*Energy_convert_sim,Timer); % (k)Wh/timestep