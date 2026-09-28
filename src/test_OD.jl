## DEFINE INPUT PARAMETERS
use_case = "ie_gb"
hour_start = 1
hour_end = 8760
isolated_zones = ["IE","NI"]
## LOAD EU grid data
file = "data/European_grid_no_nseh.json"
#gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(joinpath(dirname(@__DIR__), file))
_PMACDC.process_additional_data!(EU_grid)

IE_grid = isolate_grid(EU_grid, isolated_zones)
add_VOLL_generators(IE_grid)

unique_zones = unique([bdc["zone"] for (bdc_id, bdc) in EU_grid["bus"]])
countries = []
for (bdc_id, bdc) in EU_grid["bus"]
    if bdc["country"] in unique_zones
        push!(countries, bdc["zone"])
        println("Zone: $(bdc["zone"]), country: $(bdc["country"])")
    end
end

for (bdc_id, bdc) in EU_grid["bus"]
    if bdc["country"] in unique_zones
        push!(countries, bdc["zone"])
        println("Zone: $(bdc["zone"]), country: $(bdc["country"])")
    end
end

add_ac_branch!(IE_grid, 4129, 5923, 10.0)
add_ac_branch!(IE_grid, 4108, 5916, 10.0)
add_ac_branch!(IE_grid, 4111, 5928, 10.0)
add_ac_branch!(IE_grid, 4103, 5897, 10.0)

for (b_id, b) in IE_grid["bus"]
    b["vmin"] = 0.9
    b["vmax"] = 1.05
end
for (br_id,br) in IE_grid["branch"]
    br["angmin"] = -pi/6
    br["angmax"] = pi/6
end

open(joinpath(dirname(@__DIR__), "data", "IE_NI_grid.json"), "w") do io
    JSON.print(io, IE_grid, 4)
end
## ########################### Testing OPF
load = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "hourly_load_IE_26.json"))
IE_grid_opf = _PM.parse_file(joinpath(dirname(@__DIR__), "data", "IE_NI_grid.json"))
timeseries = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "time_series_IE_26.json"))
HVDC_flow = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "power_flow_IE_to_GB_26.json"))

##
start_hour = 1
end_hour = 24
actual_load = [load["$t"]["actual_load"] for t in start_hour:end_hour]
Plots.plot(actual_load)
unique_type = unique([g["type"] for (g_id, g) in IE_grid_opf["gen"]])

# Apply the function to fix the actual load values
actual_load = fix_zero_loads(actual_load, start_hour, end_hour)

## Run simulation
res_opf = hourly_opf(IE_grid_opf,timeseries,"cap_factor_day_ahead_hourly",actual_load,start_hour,end_hour,ACPPowerModel,Ipopt.Optimizer)

## Check results
term_statuses = [res_opf["$t"]["primal_status"] for t in start_hour:end_hour]
countmap(term_statuses)
for t in start_hour:end_hour
    delete!(res_opf["$t"],"objective_lb")
end

open(joinpath(dirname(@__DIR__), "results", "LPAC_OPF_no_HVDC_$(start_hour)_$(end_hour).json"), "w") do io
    JSON.print(io, res_opf, 4)
end

obj = [res_opf["$t"]["objective"] for t in start_hour:end_hour]
primal_status = [res_opf["$t"]["primal_status"] for t in start_hour:end_hour]
gen_per_type = Dict{String,Any}()
for g in unique_type
    gen_per_type[g] = []
end
for t in start_hour:end_hour
    for type in unique_type
        gen_type = 0
        for (g_id,g) in IE_grid_opf["gen"]
            if g["type"] == type && haskey(res_opf["$t"]["solution"]["gen"],g_id)
                gen_type += res_opf["$t"]["solution"]["gen"][g_id]["pg"]
            end
        end
        push!(gen_per_type[type], gen_type)
    end
end
biomass_gen = gen_per_type["Biomass"]
wind_gen = gen_per_type["Onshore"]
gas_gen = gen_per_type["Gas"]
oil_gen = gen_per_type["Oil"]
hydro_gen = gen_per_type["Hydro Run-of-River"]
import_HVDC = [HVDC_flow["$t"]["from_GB_to_IE"] for t in 1:24]
gas_gen_corrected = gas_gen[start_hour:end_hour]*100 .- import_HVDC 

Plots.plot(biomass_gen*100, label = "Biomass", color = :green, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(wind_gen*100, label = "Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(gas_gen_corrected, label = "Gas", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(oil_gen*100, label = "Oil", color = :orange, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(hydro_gen*100, label = "Hydro", color = :purple, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")

### Comparing results with data we got
data_IE_hackathon = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "gen_IE.json"))

biomass_gen_hack = [data_IE_hackathon["$t"]["type"]["Fossil Peat"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
wind_gen_hack  = [data_IE_hackathon["$t"]["type"]["Wind Onshore"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
gas_gen_hack   = [data_IE_hackathon["$t"]["type"]["Fossil Gas"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
oil_gen_hack   = [data_IE_hackathon["$t"]["type"]["Fossil Oil"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]
hydro_gen_hack = [data_IE_hackathon["$t"]["type"]["Hydro Run-of-river and poundage"] for t in 1:length(data_IE_hackathon) if data_IE_hackathon["$t"]["minute"] == "00"]

Plots.plot(biomass_gen_hack[1:end_hour], label = "Biomass", color = :green, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(wind_gen_hack[1:end_hour], label = "Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(gas_gen_hack[1:end_hour], label = "Gas", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(oil_gen_hack[1:end_hour], label = "Oil", color = :orange, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")
Plots.plot!(hydro_gen_hack[1:end_hour], label = "Hydro", color = :purple, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]")