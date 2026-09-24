# Processing aggregated power flows through the interconnectors
# Script to analyze data
using CSV, JSON
using DataFrames
using Dates
using Plots

const DATA_DIR = joinpath(dirname(@__DIR__),"data")

load_26 = CSV.read(joinpath(DATA_DIR, "GUI_TOTAL_LOAD_DAYAHEAD_202512312300-202612312300.csv"), DataFrame)
load_25 = CSV.read(joinpath(DATA_DIR, "GUI_TOTAL_LOAD_DAYAHEAD_202412312300-202512312300.csv"), DataFrame)

load_25[:,1]

function process_load(dict_data)
    dict_pf = Dict{String,Any}()
    dict_pf_hourly = Dict{String,Any}()
    count_ = 0
    count_hour = 0
    for t in 1:length(dict_data[:,1])
        timestamp_str = string(dict_data[t,1])
        count_ += 1
        dict_pf["$count_"] = Dict{String,Any}()
        dict_pf["$count_"]["day"] = timestamp_str[1:2]
        dict_pf["$count_"]["month"] = timestamp_str[4:5]
        dict_pf["$count_"]["year"] = timestamp_str[7:10]
        dict_pf["$count_"]["hour"] = timestamp_str[12:13]
        dict_pf["$count_"]["minute"] = timestamp_str[15:16]
        dict_pf["$count_"]["value"] = true
        if dict_data[t,3] == "N/A" || dict_data[t,3] == "-"
            dict_pf["$count_"]["actual_load"] = 0.0
            dict_pf["$count_"]["value"] = false
        else
            dict_pf["$count_"]["actual_load"] = parse(Float64, dict_data[t,3])
        end
        if dict_data[t,4] == "N/A" || dict_data[t,4] == "-"
            dict_pf["$count_"]["day_ahead_load"] = 0.0
            dict_pf["$count_"]["value"] = false
        else
            dict_pf["$count_"]["day_ahead_load"] = parse(Float64, dict_data[t,4])
        end
        if timestamp_str[15:16] == "00"
            count_hour += 1
            dict_pf_hourly["$count_hour"] = Dict{String,Any}()
            dict_pf_hourly["$count_hour"]["day"] = timestamp_str[1:2]
            dict_pf_hourly["$count_hour"]["month"] = timestamp_str[4:5]
            dict_pf_hourly["$count_hour"]["year"] = timestamp_str[7:10]
            dict_pf_hourly["$count_hour"]["hour"] = timestamp_str[12:13]
            dict_pf_hourly["$count_hour"]["minute"] = timestamp_str[15:16]
            dict_pf_hourly["$count_hour"]["value"] = true
            if dict_data[t,3] == "N/A" || dict_data[t,3] == "-"
                dict_pf_hourly["$count_hour"]["actual_load"] = 0.0
                dict_pf_hourly["$count_hour"]["value"] = false
            else
                dict_pf_hourly["$count_hour"]["actual_load"] = parse(Float64, dict_data[t,3])
            end
            if dict_data[t,4] == "N/A" || dict_data[t,4] == "-"
                dict_pf_hourly["$count_hour"]["day_ahead_load"] = 0.0
                dict_pf_hourly["$count_hour"]["value"] = false
            else
                dict_pf_hourly["$count_hour"]["day_ahead_load"] = parse(Float64, dict_data[t,4])
            end
        end
    end
    return dict_pf, dict_pf_hourly
end
dict_load_25, dict_load_hourly_25 = process_load(load_25)
dict_load_26, dict_load_hourly_26 = process_load(load_26)

open(joinpath(dirname(@__DIR__), "data", "load_IE_25.json"), "w") do io
    JSON.print(io, dict_load_25, 4)
end
open(joinpath(dirname(@__DIR__), "data", "hourly_load_IE_25.json"), "w") do io
    JSON.print(io, dict_load_hourly_25, 4)
end

open(joinpath(dirname(@__DIR__), "data", "load_IE_26.json"), "w") do io
    JSON.print(io, dict_load_26, 4)
end
open(joinpath(dirname(@__DIR__), "data", "hourly_load_IE_26.json"), "w") do io
    JSON.print(io, dict_load_hourly_26, 4)
end
actual_hourly_25 = [dict_load_hourly_25["$i"]["actual_load"] for i in 1:length(dict_load_hourly_25)]
actual_hourly_26 = [dict_load_hourly_26["$i"]["actual_load"] for i in 1:length(dict_load_hourly_26)]

day_ahead_hourly_25 = [dict_load_hourly_25["$i"]["day_ahead_load"] for i in 1:length(dict_load_hourly_25)]
day_ahead_hourly_26 = [dict_load_hourly_26["$i"]["day_ahead_load"] for i in 1:length(dict_load_hourly_26)]

Plots.scatter(1:length(actual_hourly_25), actual_hourly_25, label = "Load IE 25", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")
Plots.scatter(1:length(actual_hourly_26), actual_hourly_26, label = "Load IE 26", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")

Plots.scatter(1:length(day_ahead_hourly_25), day_ahead_hourly_25, label = "Load IE 25", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")
Plots.scatter(1:length(day_ahead_hourly_26), day_ahead_hourly_26, label = "Load IE 26", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")


Plots.scatter(1:length(actual_hourly_26), actual_hourly_26, label = "Actual load", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")
Plots.scatter!(1:length(day_ahead_hourly_26), day_ahead_hourly_26, label = "Day-ahead load", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")


Plots.scatter(1:length(actual_hourly_25), actual_hourly_25, label = "Actual load", color = :red, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")
Plots.scatter!(1:length(day_ahead_hourly_25), day_ahead_hourly_25, label = "Day-ahead load", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Load [MW]")

xline = range(0, 6000, length = 6000)
Plots.scatter(actual_hourly_26, day_ahead_hourly_26, label = "Actual vs day-ahead load", color = :red, legend = :outertopright, xlabel = "Actual load [MW]", ylabel = "Day-ahead load [MW]")
Plots.plot!(xline,xline, label = "Actual = day-ahead", color = :black, legend = :outertopright, xlabel = "Load [MW]", ylabel = "Load [MW]")