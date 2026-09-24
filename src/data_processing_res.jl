# Processing aggregated power flows through the interconnectors
# Script to analyze data
using CSV, JSON
using DataFrames
using Dates
using Plots

const DATA_DIR = joinpath(dirname(@__DIR__),"data")

res_26 = CSV.read(joinpath(DATA_DIR, "GUI_WIND_SOLAR_GENERATION_FORECAST_ONSHORE_202512312300-202612312300.csv"), DataFrame)
res_25 = CSV.read(joinpath(DATA_DIR, "GUI_WIND_SOLAR_GENERATION_FORECAST_ONSHORE_202412312300-202512312300.csv"), DataFrame)


function compute_timeseries(res)
    time_series = Dict{String,Any}()
    day_ahead_hourly = []
    actual_hourly = []
    cap_factor_day_ahead_hourly = []
    cap_factor_actual_hourly = []
    for i in 1:length(res[:,1])
        if res[i,3] == "N/A" || res[i,3] == "-" || res[i,3] == " "
            push!(day_ahead_hourly, 0.0)
        else
            push!(day_ahead_hourly, parse(Float64, res[i,3]))
        end
        if res[i,5] == "N/A" || res[i,5] == "-" || res[i,5] == " "
            push!(actual_hourly, 0.0)
        else
            push!(actual_hourly, parse(Float64, res[i,5]))
        end
    end
    cap_factor_day_ahead_hourly = day_ahead_hourly./5000
    cap_factor_actual_hourly = actual_hourly./5000
    time_series["day_ahead_hourly"] = day_ahead_hourly
    time_series["actual_hourly"] = actual_hourly
    time_series["cap_factor_day_ahead_hourly"] = cap_factor_day_ahead_hourly
    time_series["cap_factor_actual_hourly"] = cap_factor_actual_hourly

    return time_series
end

time_series_25 = compute_timeseries(res_25)
time_series_26 = compute_timeseries(res_26)


open(joinpath(dirname(@__DIR__), "data", "time_series_IE_26.json"), "w") do io
    JSON.print(io, time_series_26, 4)
end
open(joinpath(dirname(@__DIR__), "data", "time_series_IE_25.json"), "w") do io
    JSON.print(io, time_series_25, 4)
end
