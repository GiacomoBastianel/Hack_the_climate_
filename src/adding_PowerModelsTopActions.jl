# Adding PMTA
using PowerModelsTopologicalActions; const _PMTP = PowerModelsTopologicalActions
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using JSON, JuMP, Gurobi, Ipopt
using PowerModels; const _PM = PowerModels

load = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "hourly_load_IE_26.json"))
IE_grid_opf = _PM.parse_file(joinpath(dirname(@__DIR__), "data", "IE_NI_grid.json"))
timeseries = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "time_series_IE_26.json"))
HVDC_flow = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "power_flow_IE_to_GB_26.json"))
start_hour = 1
end_hour = 72
res_opf = JSON.parsefile(joinpath(dirname(@__DIR__), "results", "LPAC_OPF_HVDC_$(start_hour)_720.json"))
actual_load = [load["$t"]["actual_load"] for t in start_hour:end_hour]
_PMACDC.process_additional_data!(IE_grid_opf)


gurobi  = JuMP.optimizer_with_attributes(Gurobi.Optimizer, "MIPGap" => 1e-3, "TimeLimit" => 180.0)
ipopt   = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

split_buses = [5894,4127, 4107]
data_split, switch_couples, extremes = _PMTP.AC_busbars_split(IE_grid_opf, split_buses)

function hourly_BuS(data,timeseries,type_res_timeseries,loadseries,HVDC_flow,start_hour,end_hour,formulation,solver)
    result = Dict{String,Any}()
    for t in start_hour:end_hour
        println("Running BuS for hour $t")
        hourly_grid = deepcopy(data)
        for (load_id, load) in hourly_grid["load"]
            if !haskey(load,"type")
                if load["zone"] == "IE"
                    load["pd"] = loadseries[t]/10^2*load["powerportion"]
                    load["qd"] = loadseries[t]*0.05/10^2*load["powerportion"]
                elseif load["zone"] == "NI"
                    load["pd"] = loadseries[t]*0.15/10^2*load["powerportion"]
                    load["qd"] = loadseries[t]*0.05*0.15/10^2*load["powerportion"]
                end
            end
        end
        for (g_id,g) in hourly_grid["gen"]
            if g["type"] == "Onshore"
                g["pmax"] = g["pmax"]*timeseries[type_res_timeseries][t]*50/58
            elseif g["type"] == "Offshore"
                g["pmax"] = 0
            elseif g["type"] == "Solar PV"
                g["pmax"] = 0
            end
        end
        import_HVDC = HVDC_flow["$t"]["from_GB_to_IE"]./100
        export_HVDC = HVDC_flow["$t"]["from_IE_to_GB"]./100
        if import_HVDC > 0.1
            for (g_id,g) in hourly_grid["gen"]
                if g["type"] == "HVDC"
                    g["pmax"] = import_HVDC./3
                end
            end
            for (load_id, load) in hourly_grid["load"]
                if haskey(load,"type")
                    load["pd"] = 0
                end
            end
        elseif import_HVDC < 0.1
            for (g_id,g) in hourly_grid["gen"]
                if g["type"] == "HVDC"
                    g["pmax"] = 0.0
                end
            end
            for (load_id, load) in hourly_grid["load"]
                if haskey(load,"type")
                    load["pd"] = export_HVDC./3
                end
            end
        end
        result["$t"] = _PMTP.run_acdc_BuS_AC(hourly_grid, formulation, solver)
    end
    return result
end

result_bus = hourly_BuS(data_split, timeseries, "cap_factor_day_ahead_hourly", actual_load, HVDC_flow, start_hour, end_hour, LPACCPowerModel, gurobi)
for t in start_hour:end_hour
    delete!(result_bus["$t"],"objective_lb")
end


result_bus_1_168 = Dict{String,Any}()
for i in 1:72
    result_bus_1_168["$i"] = deepcopy(result_bus["$i"])
end

results_folder = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/Hack_the_climate/Results"
open(joinpath(dirname(@__DIR__), "data", "IE_NI_grid_with_HVDC_TAs_1_72.json"), "w") do io
    JSON.print(io, result_bus_1_168, 4)
end


obj_bus = [result_bus["$t"]["objective"] for t in 1:72]
obj_opf = [res_opf["$t"]["objective"] for t in 1:72]

primal_status_bus = [result_bus["$t"]["primal_status"] for t in start_hour:end_hour]
primal_status_opf = [res_opf["$t"]["primal_status"] for t in start_hour:end_hour]

gen_per_type_bus = Dict{String,Any}()
gen_per_type_opf = Dict{String,Any}()
unique_type = unique([g["type"] for (g_id, g) in IE_grid_opf["gen"]])

for g in unique_type
    gen_per_type_bus[g] = []
    gen_per_type_opf[g] = []
end

for t in start_hour:end_hour
    if string(res_opf["$t"]["primal_status"]) == "FEASIBLE_POINT"
        for type in unique_type
            gen_type = 0
            for (g_id,g) in IE_grid_opf["gen"]
                if g["type"] == type && haskey(res_opf["$t"]["solution"]["gen"],g_id)
                    gen_type += res_opf["$t"]["solution"]["gen"][g_id]["pg"]
                end
            end
            push!(gen_per_type_opf[type], gen_type)
        end
    end
end
for t in start_hour:end_hour
    if string(result_bus["$t"]["primal_status"]) == "FEASIBLE_POINT"
        for type in unique_type
            gen_type = 0
            for (g_id,g) in IE_grid_opf["gen"]
                if g["type"] == type && haskey(result_bus["$t"]["solution"]["gen"],g_id)
                    gen_type += result_bus["$t"]["solution"]["gen"][g_id]["pg"]
                end
            end
            push!(gen_per_type_bus[type], gen_type)
        end
    end
end


biomass_gen = gen_per_type["Biomass"]
wind_gen = gen_per_type["Onshore"]
gas_gen = gen_per_type["Gas"]
oil_gen = gen_per_type["Oil"]
import_gen = gen_per_type["HVDC"]
import_HVDC = [HVDC_flow["$t"]["from_GB_to_IE"] for t in start_hour:end_hour]
export_HVDC = [HVDC_flow["$t"]["from_IE_to_GB"] for t in start_hour:end_hour]
hydro_gen = gen_per_type["Hydro Run-of-River"]

######
function compute_metrics_per_bus(test_case,result_opf,hour)
    dict = Dict{String,Any}()
    result_opf_hour = result_opf["$hour"]
    for (b_id,b) in test_case["bus"]
        dict["$b_id"] = Dict{String,Any}()
        dict["$b_id"]["lam_kcl_r"] = abs(result_opf_hour["solution"]["bus"][b_id]["lam_kcl_r"])
        dict["$b_id"]["diff"] = 0.0
        dict["$b_id"]["n_branches"] = 0
        dict["$b_id"]["connected_branches"] = Dict{String,Any}()
    end
    for (b_id,b) in test_case["branch"]
        f_bus = b["f_bus"]
        t_bus = b["t_bus"]
        dict["$f_bus"]["connected_branches"]["$b_id"] = Dict{String,Any}()
        dict["$t_bus"]["connected_branches"]["$b_id"] = Dict{String,Any}()
        dict["$f_bus"]["connected_branches"]["$b_id"]["utilization"] = abs(result_opf_hour["solution"]["branch"][b_id]["pf"])/ b["rate_a"]
        dict["$t_bus"]["connected_branches"]["$b_id"]["utilization"] = abs(result_opf_hour["solution"]["branch"][b_id]["pf"])/ b["rate_a"]
        dict["$f_bus"]["connected_branches"]["$b_id"]["va_fr"] = result_opf_hour["solution"]["bus"]["$(f_bus)"]["va"]
        dict["$t_bus"]["connected_branches"]["$b_id"]["va_fr"] = result_opf_hour["solution"]["bus"]["$(f_bus)"]["va"]
        dict["$f_bus"]["connected_branches"]["$b_id"]["va_to"] = result_opf_hour["solution"]["bus"]["$(t_bus)"]["va"]
        dict["$t_bus"]["connected_branches"]["$b_id"]["va_to"] = result_opf_hour["solution"]["bus"]["$(t_bus)"]["va"]
        dict["$f_bus"]["connected_branches"]["$b_id"]["va_fr_minus_va_to"] = result_opf_hour["solution"]["bus"]["$(f_bus)"]["va"] - result_opf_hour["solution"]["bus"]["$(t_bus)"]["va"]
        dict["$t_bus"]["connected_branches"]["$b_id"]["va_fr_minus_va_to"] = result_opf_hour["solution"]["bus"]["$(f_bus)"]["va"] - result_opf_hour["solution"]["bus"]["$(t_bus)"]["va"]

        diff = abs(dict["$f_bus"]["lam_kcl_r"] - dict["$t_bus"]["lam_kcl_r"])
        dict["$f_bus"]["diff"] += diff
        dict["$t_bus"]["diff"] += diff
        dict["$f_bus"]["n_branches"] += 1
        dict["$t_bus"]["n_branches"] += 1
    end
    return dict
end
metrics = compute_metrics_per_bus(IE_grid_opf,res_opf_parsed,1)

sort(collect(keys(metrics)), by = x -> metrics[x]["diff"], rev = true)[1:10]
metrics["5894"]
metrics["4127"]
metrics["4107"]
buses = [5894,4127, 4107]
