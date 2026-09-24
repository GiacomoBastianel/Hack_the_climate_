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

######### DEFINE INPUT PARAMETERS
use_case = "ie_gb"
hour_start = 1
hour_end = 8760
isolated_zones = ["IE"]
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

unique_zones = unique([bdc["zone"] for (bdc_id, bdc) in EU_grid["busdc"]])
countries = []
for (bdc_id, bdc) in EU_grid["bus"]
    if bdc["country"] in unique_zones
        push!(countries, bdc["zone"])
        println("Zone: $(bdc["zone"]), country: $(bdc["country"])")
    end
end

open(joinpath(dirname(@__DIR__), "data", "IE_grid.json"), "w") do io
    JSON.print(io, IE_grid, 4)
end

#############################

IE_grid_opf = _PM.parse_file(joinpath(dirname(@__DIR__), "data", "IE_grid.json"))

