import PowerModelsTopologicalActions as _PMTP
using Juniper

gurobi  = JuMP.optimizer_with_attributes(Gurobi.Optimizer, "MIPGap" => 5e-3)
ipopt   = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer,
              "nl_solver" => ipopt, "mip_solver" => gurobi)
 
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
 
data = _PM.parse_file("data/IE_NI_grid.json")
# _PMACDC.process_additional_data!(data)
 
# --- baseline ---
result_opf = _PM.solve_opf(data, LPACCPowerModel, ipopt; setting = s)
  
## Collect AC 220 KV ac buses
buses_220_kv = []
for (bus_id, bus) in data["bus"]
    if bus["base_kv"] == 220
        push!(buses_220_kv,bus_id)
    end
end
##
# --- busbar splitting: prepare → solve → check ---
data_split, switch_couples, extremes = _PMTP.AC_busbars_split(data, 4240)


result_bus = _PMTP.run_acdc_BuS_AC(data_split, LPACCPowerModel, gurobi)
 
data_fc = deepcopy(data_split)
_PMTP.prepare_AC_feasibility_check_AC_busbars(result_bus, data_split, data_fc, switch_couples, extremes, data)
result_fc = _PM.solve_opf(data_fc, LPACCPowerModel, gurobi; setting = s)
 
println("baseline:  ", result_opf["objective"])   # 194.139 $/h
println("after BuS: ", result_fc["objective"])    # 186.349 $/h  → 4.0 % savin


##
compute_metrics_per_bus(data, LPACCPowerModel, gurobi)


## Need to find the buses
