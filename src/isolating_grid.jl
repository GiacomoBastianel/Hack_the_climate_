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

######### DEFINE INPUT PARAMETERS
use_case = "ie_gb"
hour_start = 1
hour_end = 8760
isolated_zones = ["IE","NI"]
############ LOAD EU grid data
file = "data/European_grid_no_nseh.json"
#gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(joinpath(dirname(@__DIR__), file))
_PMACDC.process_additional_data!(EU_grid)


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
IE_grid = isolate_grid(EU_grid, isolated_zones)

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
add_VOLL_generators(IE_grid)


unique_zones = unique([bdc["zone"] for (bdc_id, bdc) in EU_grid["bus"]])
countries = []
for (bdc_id, bdc) in EU_grid["bus"]
    if bdc["country"] in unique_zones
        push!(countries, bdc["zone"])
        println("Zone: $(bdc["zone"]), country: $(bdc["country"])")
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
    grid_data["branch"]["$br_idx"]["g_to"] = 1.0
    grid_data["branch"]["$br_idx"]["g_fr"] = 1.0
    grid_data["branch"]["$br_idx"]["b_fr"] = 10.0
    grid_data["branch"]["$br_idx"]["b_to"] = 10.0
    grid_data["branch"]["$br_idx"]["base_kv"] = 220
    grid_data["branch"]["$br_idx"]["source_id"] = []
    push!(grid_data["branch"]["$br_idx"]["source_id"],"branch")
    push!(grid_data["branch"]["$br_idx"]["source_id"],br_idx)
    grid_data["branch"]["$br_idx"]["br_status"] = 1
    grid_data["branch"]["$br_idx"]["shift"] = 0.0
    grid_data["branch"]["$br_idx"]["ratio"] = 1
    grid_data["branch"]["$br_idx"]["angmin"] = - 1.0472
    grid_data["branch"]["$br_idx"]["angmax"] = 1.0472
    
    return br_idx
end

add_ac_branch!(IE_grid, 4129, 5923, 10.0)
add_ac_branch!(IE_grid, 4108, 5916, 10.0)
add_ac_branch!(IE_grid, 4111, 5928, 10.0)
add_ac_branch!(IE_grid, 4103, 5897, 10.0)


#=
for (b_id, b) in IE_grid["bus"]
    if b["base_kv"] == 110 && b["lon"] > -8 && b["lon"] < -7.2 && b["lat"] < 55 && b["lat"] > 54.5
        println("Bus ID: $b_id, Lat: $(b["lat"]), Lon: $(b["lon"])")
    end
end
=#

for (b_id, b) in IE_grid["bus"]
    b["vmin"] = 0.9
    b["vmax"] = 1.1
end
for (br_id,br) in IE_grid["branch"]
    br["angmin"] = -pi/3
    br["angmax"] = pi/3
end

function add_generator!(grid_data, gen_bus, power_rating, gen_zone, gen_type, gen_costs; gen_id = nothing, status = 1)     
    if isnothing(gen_id)
        gen_idx = maximum([gen["index"] for (g, gen) in grid_data["gen"]]) + 1
    else
        gen_idx = gen_id
    end
    grid_data["gen"]["$gen_idx"] = Dict{String, Any}()  
    grid_data["gen"]["$gen_idx"]["zone"] = gen_zone  
    grid_data["gen"]["$gen_idx"]["type_tyndp"] = gen_type
    grid_data["gen"]["$gen_idx"]["model"] = 2  
    grid_data["gen"]["$gen_idx"]["gen_bus"] = gen_bus
    grid_data["gen"]["$gen_idx"]["pmax"] = power_rating 
    grid_data["gen"]["$gen_idx"]["vg"] = 1.0
    grid_data["gen"]["$gen_idx"]["source_id"] = []
    push!(grid_data["gen"]["$gen_idx"]["source_id"],"gen")
    push!(grid_data["gen"]["$gen_idx"]["source_id"],gen_idx)
    grid_data["gen"]["$gen_idx"]["index"] = gen_idx
    grid_data["gen"]["$gen_idx"]["cost"] = []
    push!(grid_data["gen"]["$gen_idx"]["cost"],gen_costs)
    push!(grid_data["gen"]["$gen_idx"]["cost"],0.0)
    grid_data["gen"]["$gen_idx"]["qmax"] = 0.0
    grid_data["gen"]["$gen_idx"]["gen_status"] = 1
    grid_data["gen"]["$gen_idx"]["qmin"] = 0.0
    grid_data["gen"]["$gen_idx"]["type"] = "HVDC" 
    grid_data["gen"]["$gen_idx"]["pmin"] = 0.0 
    grid_data["gen"]["$gen_idx"]["ncost"] = 2 
    
    return gen_idx
end

function add_load!(grid_data, load_bus, peak_power, load_zone; load_id = nothing, status = 1) 
    
    if isnothing(load_id)
        load_idx = maximum([load["index"] for (g, load) in grid_data["load"]]) + 1
    else
        load_idx = load_id
    end
    grid_data["load"]["$load_idx"] = Dict{String, Any}()  
    grid_data["load"]["$load_idx"]["zone"] = load_zone  
    grid_data["load"]["$load_idx"]["load_bus"] = load_bus
    grid_data["load"]["$load_idx"]["pmax"] = peak_power 
    grid_data["load"]["$load_idx"]["pmin"] = 0.0 
    grid_data["load"]["$load_idx"]["pd"] = 0.1 
    grid_data["load"]["$load_idx"]["qd"] = 0.0 
    grid_data["load"]["$load_idx"]["status"] = 1 
    grid_data["load"]["$load_idx"]["source_id"] = []
    grid_data["load"]["$load_idx"]["type"] = "HVDC"
    push!(grid_data["load"]["$load_idx"]["source_id"],"bus")
    push!(grid_data["load"]["$load_idx"]["source_id"],load_bus)
    grid_data["load"]["$load_idx"]["index"] = load_idx
    
    return load_idx
end

add_generator!(IE_grid, 5903, 5.0, "NI", "HVDC",1.0)
add_generator!(IE_grid, 4150, 5.0, "IE", "HVDC",1.0)
add_generator!(IE_grid, 4276, 5.0, "IE", "HVDC",1.0)

add_load!(IE_grid, 5903, 5.0, "NI")
add_load!(IE_grid, 4150, 5.0, "IE")
add_load!(IE_grid, 4276, 5.0, "IE")

open(joinpath(dirname(@__DIR__), "data", "IE_NI_grid_with_HVDC.json"), "w") do io
    JSON.print(io, IE_grid, 4)
end


############################# Testing OPF
load = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "hourly_load_IE_26.json"))
IE_grid_opf = _PM.parse_file(joinpath(dirname(@__DIR__), "data", "IE_NI_grid.json"))
timeseries = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "time_series_IE_26.json"))
HVDC_flow = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "power_flow_IE_to_GB_26.json"))

start_hour = 1
end_hour = 720
actual_load = [load["$t"]["actual_load"] for t in start_hour:end_hour]
Plots.plot(actual_load)
unique_type = unique([g["type"] for (g_id, g) in IE_grid_opf["gen"]])

function hourly_opf(data,timeseries,type_res_timeseries,loadseries,HVDC_flow,start_hour,end_hour,formulation,solver)
    result = Dict{String,Any}()
    for t in start_hour:end_hour
        println("Running OPF for hour $t")
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
        result["$t"] = _PM.solve_opf(hourly_grid, formulation, solver)
    end
    return result
end

res_opf_parsed = hourly_opf(IE_grid_opf,timeseries,"cap_factor_day_ahead_hourly",actual_load,HVDC_flow,start_hour,end_hour,LPACCPowerModel,Ipopt.Optimizer)
#res_opf = hourly_opf(IE_grid,timeseries,"cap_factor_day_ahead_hourly",actual_load,HVDC_flow,start_hour,end_hour,LPACCPowerModel,Ipopt.Optimizer)

term_statuses_parsed = [res_opf_parsed["$t"]["primal_status"] for t in start_hour:end_hour]

#obj = [res_opf["$t"]["objective"] for t in start_hour:end_hour]
obj_parsed = [res_opf_parsed["$t"]["objective"] for t in start_hour:end_hour]

#obj_diff = [obj[t] - obj_parsed[t] for t in 1:length(obj)]
#diff_perc = obj_diff./obj_parsed*100
#plot(diff_perc, label = "Objective difference [%]", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Difference [%]")
countmap(term_statuses_parsed)
for t in start_hour:end_hour
    delete!(res_opf_parsed["$t"],"objective_lb")
end

open(joinpath(dirname(@__DIR__), "results", "LPAC_OPF_HVDC_$(start_hour)_$(end_hour).json"), "w") do io
    JSON.print(io, res_opf_parsed, 4)
end

obj = [res_opf_parsed["$t"]["objective"] for t in start_hour:end_hour]
primal_status = [res_opf_parsed["$t"]["primal_status"] for t in start_hour:end_hour]
gen_per_type = Dict{String,Any}()
for g in unique_type
    gen_per_type[g] = []
end

string(res_opf_parsed["1"]["primal_status"])

for t in start_hour:end_hour
    if string(res_opf_parsed["$t"]["primal_status"]) == "FEASIBLE_POINT"
        for type in unique_type
            gen_type = 0
            for (g_id,g) in IE_grid_opf["gen"]
                if g["type"] == type && haskey(res_opf_parsed["$t"]["solution"]["gen"],g_id)
                    gen_type += res_opf_parsed["$t"]["solution"]["gen"][g_id]["pg"]
                end
            end
            push!(gen_per_type[type], gen_type)
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

plot(export_HVDC, label = "Export", color = :gray, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")

import_HVDC - import_gen*100
Plots.plot(import_HVDC, label = "Import", color = :gray, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(import_gen*100,label = "Computed import")

Plots.plot(biomass_gen*100, label = "Biomass", color = :green, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(wind_gen*100, label = "Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(gas_gen*100, label = "Gas", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(import_gen*100, label = "Import", color = :gray, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(-export_HVDC, label = "Export", color = :gray, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(oil_gen*100, label = "Oil", color = :orange, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(hydro_gen*100, label = "Hydro", color = :purple, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")

### Comparing results with data we got
data_IE_hackathon = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "gen_IE.json"))

biomass_gen_hack = [data_IE_hackathon["$t"]["type"]["Fossil Peat"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
wind_gen_hack  = [data_IE_hackathon["$t"]["type"]["Wind Onshore"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
gas_gen_hack   = [data_IE_hackathon["$t"]["type"]["Fossil Gas"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
oil_gen_hack   = [data_IE_hackathon["$t"]["type"]["Fossil Oil"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
hydro_gen_hack = [data_IE_hackathon["$t"]["type"]["Hydro Run-of-river and poundage"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]

Plots.plot(biomass_gen_hack[1:168], label = "Biomass", color = :green, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(wind_gen_hack[1:168], label = "Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(gas_gen_hack[1:168], label = "Gas", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(oil_gen_hack[1:168], label = "Oil", color = :orange, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(hydro_gen_hack[1:168], label = "Hydro", color = :purple, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")

###################

# Adding HVDC generators
IE_grid["bus"]["5903"]
IE_grid["bus"]["4150"]
IE_grid["bus"]["4276"]

maximum([gen["index"] for (g, gen) in IE_grid["gen"]])
IE_grid["gen"]["7502"]
IE_grid["gen"]["7503"]
IE_grid["gen"]["7504"]

