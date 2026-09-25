## Computing curtailment
# Uploading grid data and OPF results
load = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "hourly_load_IE_26.json"))
IE_grid_opf = _PM.parse_file(joinpath(dirname(@__DIR__), "data", "IE_NI_grid.json"))
timeseries = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "time_series_IE_26.json"))
HVDC_flow = JSON.parsefile(joinpath(dirname(@__DIR__), "data", "power_flow_IE_to_GB_26.json"))
start_hour = 1
end_hour = 168
res_opf = JSON.parsefile(joinpath(dirname(@__DIR__), "results", "LPAC_OPF_no_HVDC_$(start_hour)_$(end_hour).json"))

obj = [res_opf["$t"]["objective"] for t in start_hour:end_hour]
primal_status = [res_opf["$t"]["primal_status"] for t in start_hour:end_hour]
unique_type = unique([g["type"] for (g_id, g) in IE_grid_opf["gen"]])
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
import_HVDC = [HVDC_flow["$t"]["from_GB_to_IE"] for t in 1:168]
gas_gen_corrected = gas_gen[start_hour:end_hour]*100 .- import_HVDC 

installed_wind_capacity = sum([g["pmax"] for (g_id,g) in IE_grid_opf["gen"] if g["type"] == "Onshore"])
max_available_wind = [timeseries["cap_factor_day_ahead_hourly"][t]*installed_wind_capacity for t in start_hour:end_hour]
curt = [max_available_wind[t]*100 - wind_gen[t]*100 for t in 1:length(wind_gen)]
plot(curt, label = "Curtailment", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Curtailment [MW]")