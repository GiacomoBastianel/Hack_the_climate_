# Processing aggregated power flows through the interconnectors
# Script to analyze data
using CSV, JSON
using DataFrames
using Dates
using Plots

const DATA_DIR = joinpath(dirname(@__DIR__),"data")

power_flows_26 = CSV.read(joinpath(DATA_DIR, "GUI_NET_CROSS_BORDER_PHYSICAL_FLOWS_202512312300-202612312300.csv"), DataFrame)
power_flows_25 = CSV.read(joinpath(DATA_DIR, "GUI_NET_CROSS_BORDER_PHYSICAL_FLOWS_202412312300-202512312300.csv"), DataFrame)

parse(Float64, power_flows_26[1,4])

power_flow_IE_to_GB_26 = Dict{String,Any}()
power_flow_IE_to_GB_25 = Dict{String,Any}()

timestamp_str = string(power_flows_26[1,1])
timestamp_str[1:2]

function compute_power_flow(dict_data)
    dict_pf = Dict{String,Any}()
    count_ = 1
    new_timestep = 1
    previous_timestep = 1
    for t in 1:length(dict_data[:,1])
        timestamp_str = string(dict_data[t,1])
        println("t: $t")
        if t == 1 
            dict_pf["$count_"] = Dict{String,Any}()
            dict_pf["$count_"]["day"] = timestamp_str[1:2]
            dict_pf["$count_"]["month"] = timestamp_str[4:5]
            dict_pf["$count_"]["year"] = timestamp_str[7:10]
            dict_pf["$count_"]["from_IE_to_GB"] = parse(Float64, dict_data[t,4])
        elseif t == 2
            count_ += 1
            if dict_pf["$(count_ - 1)"]["day"] == timestamp_str[1:2] && dict_pf["$(count_ - 1)"]["month"] == timestamp_str[4:5] && dict_pf["$(count_ - 1)"]["year"] == timestamp_str[7:10]
                dict_pf["$(count_ - 1)"]["from_GB_to_IE"] = parse(Float64, dict_data[t,4])
            else
                new_timestep += 1
                dict_pf["$(count_ - 1)"]["from_IE_to_GB"] = parse(Float64, dict_data[t,4])
            end
        elseif t >= 2
            if dict_pf["$(new_timestep)"]["day"] == timestamp_str[1:2] && dict_pf["$(new_timestep - 1)"]["month"] == timestamp_str[4:5] && dict_pf["$(new_timestep - 1)"]["year"] == timestamp_str[7:10]
                dict_pf["$(new_timestep)"]["from_GB_to_IE"] = parse(Float64, dict_data[t,4])
            else
                new_timestep += 1
                dict_pf["$new_timestep"] = Dict{String,Any}()
                dict_pf["$new_timestep"]["day"] = timestamp_str[1:2]
                dict_pf["$new_timestep"]["month"] = timestamp_str[4:5]
                dict_pf["$new_timestep"]["year"] = timestamp_str[7:10]
                dict_pf["$new_timestep"]["from_IE_to_GB"] = parse(Float64, dict_data[t,4])
            end
        end
    end
    return dict_pf
end

function compute_power_flow(dict_data)
    dict_pf = Dict{String,Any}()
    count_ = 0
    for t in 1:length(dict_data[:,1])
        timestamp_str = string(dict_data[t,1])
        println("t: $t")
        if isodd(t) 
            count_ += 1
            dict_pf["$count_"] = Dict{String,Any}()
            dict_pf["$count_"]["day"] = timestamp_str[1:2]
            dict_pf["$count_"]["month"] = timestamp_str[4:5]
            dict_pf["$count_"]["year"] = timestamp_str[7:10]
            dict_pf["$count_"]["value"] = true
            if dict_data[t,4] == "N/A" || dict_data[t,4] == "-"
                dict_pf["$count_"]["from_IE_to_GB"] = 0.0
                dict_pf["$count_"]["value"] = false
            else
                dict_pf["$count_"]["from_IE_to_GB"] = parse(Float64, dict_data[t,4])
            end
        else  
            if dict_data[t,4] == "N/A" || dict_data[t,4] == "-"
                dict_pf["$count_"]["from_GB_to_IE"] = 0.0
                dict_pf["$count_"]["value"] = false
            else
                dict_pf["$count_"]["from_GB_to_IE"] = parse(Float64, dict_data[t,4])
            end
        end
    end
    return dict_pf
end

power_flow_IE_to_GB_25 = compute_power_flow(power_flows_25)
power_flow_IE_to_GB_26 = compute_power_flow(power_flows_26)

open(joinpath(dirname(@__DIR__), "data", "power_flow_IE_to_GB_25.json"), "w") do io
    JSON.print(io, power_flow_IE_to_GB_25, 4)
end

open(joinpath(dirname(@__DIR__), "data", "power_flow_IE_to_GB_26.json"), "w") do io
    JSON.print(io, power_flow_IE_to_GB_26, 4)
end

power_flow_IE_to_GB_25["1"]
GB_to_IE = [power_flow_IE_to_GB_25["$t"]["from_GB_to_IE"] for t in 1:length(power_flow_IE_to_GB_25)]
IE_to_GB = [power_flow_IE_to_GB_25["$t"]["from_IE_to_GB"] for t in 1:length(power_flow_IE_to_GB_25)]

Plots.scatter(1:length(GB_to_IE), GB_to_IE, label = "GB to IE", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Power flow [MW]")
Plots.scatter(1:length(IE_to_GB), IE_to_GB, label = "IE to GB", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Power flow [MW]")




