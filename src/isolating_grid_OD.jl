# Isolating grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using JSON
using Plots
using JuMP
using Gurobi  # needs startvalues for all variables!
using JSON
using DataFrames; const _DF = DataFrames
using CSV
using StatsBase
using Ipopt
using PowerModelsTopologicalActions

function isolate_grid(EU_grid, isolated_zones)
    isolated_grid = deepcopy(EU_grid)
    isolated_grid["bus"] = Dict{String,Any}()
    isolated_grid["branch"] = Dict{String,Any}()
    isolated_grid["gen"] = Dict{String,Any}()
    isolated_grid["load"] = Dict{String,Any}()
    isolated_grid["shunt"] = Dict{String,Any}()
    isolated_grid["storage"] = Dict{String,Any}()
    isolated_grid["busdc"] = Dict{String,Any}()
    isolated_grid["branchdc"] = Dict{String,Any}()
    isolated_grid["convdc"] = Dict{String,Any}()
    
    for (bus_id, bus) in EU_grid["bus"]
        if bus["zone"] in isolated_zones
            isolated_grid["bus"][bus_id] = deepcopy(bus)
        end
    end
    for (branch_id, branch) in EU_grid["branch"]
        if "$(branch["f_bus"])" in keys(isolated_grid["bus"]) && "$(branch["t_bus"])" in keys(isolated_grid["bus"])
            isolated_grid["branch"][branch_id] = deepcopy(branch)
        end
    end
    for (gen_id, gen) in EU_grid["gen"]
        if gen["zone"] in isolated_zones
            isolated_grid["gen"][gen_id] = deepcopy(gen)
        end
    end
    for (load_id, load) in EU_grid["load"]
        if load["zone"] in isolated_zones
            isolated_grid["load"][load_id] = deepcopy(load)
        end
    end
    #for (shunt_id, shunt) in EU_grid["shunt"]
    #    if shunt["bus"] in keys(isolated_grid["bus"])
    #        isolated_grid["shunt"][shunt_id] = deepcopy(shunt)
    #    end
    #end
    for (busdc_id, busdc) in EU_grid["busdc"]
        if busdc["zone"] in isolated_zones
            isolated_grid["busdc"][busdc_id] = deepcopy(busdc)
        end
    end
    for (branchdc_id, branchdc) in EU_grid["branchdc"]
        if branchdc["fbusdc"] in keys(isolated_grid["busdc"]) && branchdc["tbusdc"] in keys(isolated_grid["busdc"])
            isolated_grid["branchdc"][branchdc_id] = deepcopy(branchdc)
        end
    end
    for (convdc_id, convdc) in EU_grid["convdc"]
        if convdc["busdc_i"] in keys(isolated_grid["busdc"]) && convdc["busac_i"] in keys(isolated_grid["bus"])
            isolated_grid["convdc"][convdc_id] = deepcopy(convdc)
        end
    end
    return isolated_grid
end

function add_VOLL_generators(data)
    first_l = maximum(parse.(Int, keys(data["gen"])))
    count = 0
    for (b_id,b) in data["bus"]
        count += 1
        l = first_l + count
        data["gen"]["$l"] = deepcopy(data["gen"]["3387"])
        data["gen"]["$l"]["gen_bus"] = parse(Int64,b_id) 
        data["gen"]["$l"]["pmax"] = 99.99
        data["gen"]["$l"]["source_id"][2] = deepcopy(l)
        data["gen"]["$l"]["index"] = l 
        data["gen"]["$l"]["type"] = "VOLL"
        data["gen"]["$l"]["cost"][1] = 10000
        data["gen"]["$l"]["zone"] = b["zone"]
        println("Added VOLL gen $l at bus $b_id")
    end
end

function add_ac_branch!(grid_data, fbus, tbus, power_rating; status = 1, r = 0.001, x = 0.01, branch_id = nothing)
    if isnothing(branch_id)
        br_idx = maximum([branch["index"] for (br, branch) in grid_data["branch"]]) + 1
    else
        br_idx = branch_id
    end
    grid_data["branch"]["$br_idx"] = Dict{String, Any}()
    grid_data["branch"]["$br_idx"]["f_bus"] = fbus
    grid_data["branch"]["$br_idx"]["t_bus"] = tbus
    grid_data["branch"]["$br_idx"]["br_r"] = r
    grid_data["branch"]["$br_idx"]["br_x"] = 0.01  
    grid_data["branch"]["$br_idx"]["rate_a"] = power_rating
    grid_data["branch"]["$br_idx"]["rate_b"] = power_rating
    grid_data["branch"]["$br_idx"]["rate_c"] = power_rating
    grid_data["branch"]["$br_idx"]["status"] = status
    grid_data["branch"]["$br_idx"]["index"] = br_idx
    grid_data["branch"]["$br_idx"]["interconnector"] = false
    grid_data["branch"]["$br_idx"]["transformer"] = false
    grid_data["branch"]["$br_idx"]["type"] = "AC line"
    grid_data["branch"]["$br_idx"]["tap"] = 1.0
    grid_data["branch"]["$br_idx"]["g_to"] = 0.0 #1.0
    grid_data["branch"]["$br_idx"]["g_fr"] = 0.0 #1.0
    grid_data["branch"]["$br_idx"]["b_fr"] = 0.0 #10.0
    grid_data["branch"]["$br_idx"]["b_to"] = 0.0 #10.0
    grid_data["branch"]["$br_idx"]["base_kv"] = 220
    grid_data["branch"]["$br_idx"]["source_id"] = []
    push!(grid_data["branch"]["$br_idx"]["source_id"],"branch")
    push!(grid_data["branch"]["$br_idx"]["source_id"],br_idx)
    grid_data["branch"]["$br_idx"]["br_status"] = 1
    grid_data["branch"]["$br_idx"]["shift"] = 0.0
    grid_data["branch"]["$br_idx"]["ratio"] = 1
    grid_data["branch"]["$br_idx"]["angmin"] = - 0.5236
    grid_data["branch"]["$br_idx"]["angmax"] = 0.5236
    
    return br_idx
end

function fix_zero_loads(load_series, start_hour, end_hour)
    for t in start_hour:end_hour
        if load_series[t] == 0.0
            if t == start_hour
                load_series[t] = load_series[t+1]
            elseif t == end_hour
                load_series[t] = load_series[t-1]
            else
                load_series[t] = (load_series[t-1] + load_series[t+1]) / 2
            end
        end
    end
    return load_series
end

function hourly_opf(data,timeseries,type_res_timeseries,loadseries,start_hour,end_hour,formulation,solver)
    result = Dict{String,Any}()
    for t in start_hour:end_hour
        println("Running OPF for hour $t")
        hourly_grid = deepcopy(data)
        for (load_id, load) in hourly_grid["load"]
            if load["zone"] == "IE"
                load["pd"] = loadseries[t]/10^2*load["powerportion"]
                load["qd"] = loadseries[t]*0.33/10^2*load["powerportion"]
            elseif load["zone"] == "NI"
                load["pd"] = loadseries[t]*0.15/10^2*load["powerportion"]
                load["qd"] = loadseries[t]*0.33*0.15/10^2*load["powerportion"]
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
        result["$t"] = _PM.solve_opf(hourly_grid, formulation, solver)
        result["data"] = hourly_grid
    end
    return result
end