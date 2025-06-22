function [Time_array,Energy_array] = Solar_generation(Number_solarpanels, Season)

Time_array = linspace(0,24,97);

Peak = 11.5;

if Season == "Summer"
    sigma = 3.1;
    energy = 5.35;
elseif Season == "Fall"
    sigma = 2.2;
    energy = 2.33;
elseif Season == "Spring"
    sigma = 2.9;
    energy = 4.56;
elseif Season == "Winter"
    sigma = 1.8;
    energy = 1.17;
end

Energy_array = energy*(Number_solarpanels/(2.5*sigma*sqrt(2*pi)))*exp(-((Time_array-Peak).^2)/(2*sigma^2));

end