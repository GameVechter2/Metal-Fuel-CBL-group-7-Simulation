Seasons = ["Summer", "Fall", "Winter", "Spring"];
color = ["y", "r", "b", "g"];

Var_state =[false, true, true, true];
Var_names = ["ideal", "beta sample 1", "beta sample 2", "beta sample 3"];

figure;
hold on
for ii = 1:length(Seasons)
    %[Time_array, Energy_array] = Solar_generation_(1, Seasons(ii));
    [Time_array, Energy_array] = Solar_generation_V2(1, "Summer", Var_state(ii),1/2);
    plot(Time_array, Energy_array, color(ii), 'LineWidth', 2);
end
%title('Energy Generated during each season (Gaussian)');
title('Energy Generated during summer, random beta efficiency');
xlabel('Time (Hours)');
ylabel("Energy Generated (kWh)");
legend(Var_names)
grid on;