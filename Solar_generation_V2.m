function [Time_array,Energy_array] = Solar_generation_V2(Number_solarpanels, Season, Var_state, Time_step)

% Time_step is part of hours, 15 minutes (1/4), 30 minutes (1/2), 1 hour (1)

length_time = 1/Time_step*24+1;
Time_array = linspace(0,24,length_time);

Peak_time = 11.5;

if Season == "Summer"
    sigma = 3.1;
    Energy = 5.35; %kWh
    sun_mean = 0.48;
    sun_var = 2.5;

elseif Season == "Fall"
    sigma = 2.2;
    Energy = 2.33; %kWh
    sun_mean = 0.385;
    sun_var = 2.4;

elseif Season == "Spring"
    sigma = 2.9;
    Energy = 4.56; %kWh
    sun_mean = 0.485;
    sun_var = 2.4;

elseif Season == "Winter"
    sigma = 1.8;
    Energy = 1.17; %kWh
    sun_mean = 0.254;
    sun_var = 1.7;
end

if Var_state == true
    efficiency = betarnd(sun_mean * sun_var, (1 - sun_mean) * sun_var);
else
    efficiency = 1;
end

base_gaussian = exp(-((Time_array - Peak_time).^2) / (2 * sigma^2));
norm_gaussian = base_gaussian / sum(base_gaussian);

total_energy = efficiency * Energy * Number_solarpanels/2.5;
Energy_array = norm_gaussian * total_energy;

end