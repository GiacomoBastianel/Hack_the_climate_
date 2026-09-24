# Script to analyze data
using CSV, JSON
using DataFrames
using Dates
using Makie, CairoMakie, Plots

const DATA_DIR = joinpath(dirname(@__DIR__),"data")
#const DATETIME_FORMAT = dateformat("yyyy-mm-dd HH:MM:SS")

read_data(file) = CSV.read(joinpath(DATA_DIR, file), DataFrame; dateformat = DATETIME_FORMAT)

generation = CSV.read(joinpath(DATA_DIR, "generation.csv"), DataFrame)
load   = CSV.read(joinpath(DATA_DIR, "load.csv"), DataFrame)
prices = CSV.read(joinpath(DATA_DIR, "prices.csv"), DataFrame)


## Generation data processing
gen_IE = Dict{String,Any}()
gen_GB = Dict{String,Any}()
count_IE = 0
count_GB = 0
gens_IE = [generation[t,4] for t in 1:length(generation[:,1]) if generation[t,2] == "IE"]
gens_GB = [generation[t,4] for t in 1:length(generation[:,1]) if generation[t,2] == "GB"]
gen_types_IE = unique(gens_IE)
gen_types_GB = unique(gens_GB)
for t in 1:length(generation[:,1])
    if generation[t,2] == "IE"
        skip = false
        timestamp_str = string(generation[t,1])
        for s in 1:count_IE
            if gen_IE["$s"]["day"] == timestamp_str[9:10] && gen_IE["$s"]["month"] == timestamp_str[6:7] && gen_IE["$s"]["year"] == timestamp_str[1:4] && gen_IE["$s"]["hour"] == timestamp_str[12:13] && gen_IE["$s"]["minute"] == timestamp_str[15:16] && gen_IE["$s"]["second"] == timestamp_str[18:19]
               skip = true
            end
        end
        if skip == false
            count_IE += 1
            gen_IE["$count_IE"] = Dict{String,Any}()
            gen_IE["$count_IE"]["day"] = timestamp_str[9:10]
            gen_IE["$count_IE"]["month"] = timestamp_str[6:7]
            gen_IE["$count_IE"]["year"] = timestamp_str[1:4]
            gen_IE["$count_IE"]["hour"] = timestamp_str[12:13]
            gen_IE["$count_IE"]["minute"] = timestamp_str[15:16]
            gen_IE["$count_IE"]["second"] = timestamp_str[18:19]
            gen_IE["$count_IE"]["type"] = Dict{String,Any}()
            for source in gen_types_IE
                gen_IE["$count_IE"]["type"]["$source"] = 0.0
            end
        end
    elseif generation[t,2] == "GB"
        skip = false
        timestamp_str = string(generation[t,1])
        for s in 1:count_GB
            if gen_GB["$s"]["day"] == timestamp_str[9:10] && gen_GB["$s"]["month"] == timestamp_str[6:7] && gen_GB["$s"]["year"] == timestamp_str[1:4] && gen_GB["$s"]["hour"] == timestamp_str[12:13] && gen_GB["$s"]["minute"] == timestamp_str[15:16] && gen_GB["$s"]["second"] == timestamp_str[18:19]
               skip = true
            end
        end
        if skip == false
            count_GB += 1
            gen_GB["$count_GB"] = Dict{String,Any}()
            gen_GB["$count_GB"]["day"] = timestamp_str[9:10]
            gen_GB["$count_GB"]["month"] = timestamp_str[6:7]
            gen_GB["$count_GB"]["year"] = timestamp_str[1:4]
            gen_GB["$count_GB"]["hour"] = timestamp_str[12:13]
            gen_GB["$count_GB"]["minute"] = timestamp_str[15:16]
            gen_GB["$count_GB"]["second"] = timestamp_str[18:19]
            gen_GB["$count_GB"]["type"] = Dict{String,Any}()
            for source in gen_types_GB
                gen_GB["$count_GB"]["type"]["$source"] = 0.0
            end
        end
    end
end
for t in 1:length(generation[:,1])
    if generation[t,2] == "IE"
        timestamp_str = string(generation[t,1])
        for s in 1:length(gen_IE)
            if gen_IE["$s"]["day"] == timestamp_str[9:10] && gen_IE["$s"]["month"] == timestamp_str[6:7] && gen_IE["$s"]["year"] == timestamp_str[1:4] && gen_IE["$s"]["hour"] == timestamp_str[12:13] && gen_IE["$s"]["minute"] == timestamp_str[15:16] && gen_IE["$s"]["second"] == timestamp_str[18:19]
                gen_IE["$s"]["type"]["$(generation[t,4])"] += generation[t,3]
            end
        end
    elseif generation[t,2] == "GB"
        timestamp_str = string(generation[t,1])
        for s in 1:length(gen_GB)
            if gen_GB["$s"]["day"] == timestamp_str[9:10] && gen_GB["$s"]["month"] == timestamp_str[6:7] && gen_GB["$s"]["year"] == timestamp_str[1:4] && gen_GB["$s"]["hour"] == timestamp_str[12:13] && gen_GB["$s"]["minute"] == timestamp_str[15:16] && gen_GB["$s"]["second"] == timestamp_str[18:19]
                gen_GB["$s"]["type"]["$(generation[t,4])"] += generation[t,3]
            end
        end
    end
end

gen_IE["1"]["type"]
gen_GB["1"]["type"]

day = []
month = []
hour = []
minute = []
second = []
for t in 1:length(gen_IE)
    push!(day   , gen_IE["$t"]["day"])
    push!(month , gen_IE["$t"]["month"])
    push!(hour  , gen_IE["$t"]["hour"])
    push!(minute, gen_IE["$t"]["minute"])
    push!(second, gen_IE["$t"]["second"])
end

open(joinpath(dirname(@__DIR__), "data", "gen_IE.json"), "w") do io
    JSON.print(io, gen_IE, 4)
end

open(joinpath(dirname(@__DIR__), "data", "gen_GB.json"), "w") do io
    JSON.print(io, gen_GB, 4)
end

generation_vectors_IE = Dict{String,Any}()
for source in gen_types_IE
    generation_vectors_IE["$source"] = []
    for t in 1:length(gen_IE)
        push!(generation_vectors_IE["$source"], gen_IE["$t"]["type"]["$source"])
    end
end

generation_vectors_GB = Dict{String,Any}()
for source in gen_types_GB
    generation_vectors_GB["$source"] = []
    for t in 1:length(gen_GB)
        push!(generation_vectors_GB["$source"], gen_GB["$t"]["type"]["$source"])
    end
end

open(joinpath(dirname(@__DIR__), "data", "generation_vectors_IE.json"), "w") do io
    JSON.print(io, generation_vectors_IE, 4)
end

open(joinpath(dirname(@__DIR__), "data", "generation_vectors_GB.json"), "w") do io
    JSON.print(io, generation_vectors_GB, 4)
end


fig = Figure()
ax = Axis(fig[1, 1],    xlabel = "Timestep [-]",
    ylabel = "Generation [MW]")
lines!(ax, 1:length(generation_vectors_IE["Wind Onshore"]), generation_vectors_IE["Wind Onshore"], color = :blue, label = "Wind")
lines!(ax, 1:length(generation_vectors_IE["Solar"]), generation_vectors_IE["Solar"], color = :orange, label = "Solar")
lines!(ax, 1:length(generation_vectors_IE["Fossil Gas"]), generation_vectors_IE["Fossil Gas"], color = :red, label = "Fossil Gas")
lines!(ax, 1:length(generation_vectors_IE["Fossil Oil"]), generation_vectors_IE["Fossil Oil"], color = :black, label = "Fossil Oil")
axislegend(ax,position = :rt,labelsize = 10)

display(fig)
#save("figure.pdf", fig)
total = [generation_vectors_IE["Wind Onshore"][t] + generation_vectors_IE["Solar"][t] + generation_vectors_IE["Fossil Gas"][t] + generation_vectors_IE["Fossil Oil"][t] + generation_vectors_IE["Fossil Peat"][t] + generation_vectors_IE["Hydro Run-of-river and poundage"][t] for t in 1:length(generation_vectors_IE["Wind Onshore"])]
Plots.plot(1:length(generation_vectors_IE["Wind Onshore"]), generation_vectors_IE["Wind Onshore"], label = "Onshore Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]",xticks = 1:(48*7):length(generation_vectors_IE["Wind Onshore"]))
Plots.plot!(1:length(generation_vectors_IE["Solar"]), generation_vectors_IE["Solar"], label = "Solar", color = :orange)
Plots.plot!(1:length(generation_vectors_IE["Fossil Gas"]), generation_vectors_IE["Fossil Gas"], label = "Fossil Gas", color = :red)
Plots.plot!(1:length(generation_vectors_IE["Fossil Oil"]), generation_vectors_IE["Fossil Oil"], label = "Fossil Oil", color = :black)
Plots.plot!(1:length(generation_vectors_IE["Fossil Peat"]), generation_vectors_IE["Fossil Peat"], label = "Fossil Peat", color = :brown)
Plots.plot!(1:length(generation_vectors_IE["Hydro Run-of-river and poundage"]), generation_vectors_IE["Hydro Run-of-river and poundage"], label = "Hydro", color = :cyan)
Plots.plot!(1:length(generation_vectors_IE["Hydro Run-of-river and poundage"]), total, label = "Total", color = :black, linestyle = :dash)

gen_hourly_IE_onw = [generation_vectors_IE["Wind Onshore"][t] for t in 1:length(generation_vectors_IE["Wind Onshore"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_pv    = [generation_vectors_IE["Solar"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_fg    = [generation_vectors_IE["Fossil Gas"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_fo    = [generation_vectors_IE["Fossil Oil"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_fp    = [generation_vectors_IE["Fossil Peat"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_hydro = [generation_vectors_IE["Hydro Run-of-river and poundage"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]

Plots.plot(1:length(generation_vectors_GB["Wind Onshore"]), generation_vectors_GB["Wind Onshore"], label = "Onshore Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]",xticks = 1:(48*7):length(generation_vectors_GB["Wind Onshore"]))
Plots.plot!(1:length(generation_vectors_GB["Wind Offshore"]), generation_vectors_GB["Wind Offshore"], label = "Offshore Wind", color = :green)
Plots.plot!(1:length(generation_vectors_GB["Solar"]), generation_vectors_GB["Solar"], label = "Solar", color = :orange)
Plots.plot!(1:length(generation_vectors_GB["Fossil Gas"]), generation_vectors_GB["Fossil Gas"], label = "Fossil Gas", color = :red)
Plots.plot!(1:length(generation_vectors_GB["Fossil Oil"]), generation_vectors_GB["Fossil Oil"], label = "Fossil Oil", color = :black)

Plots.plot(1:length(gen_hourly_IE_onw), gen_hourly_IE_onw, label = "Onshore Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]",xticks = 1:(24):length(gen_hourly_IE_onw))
Plots.plot!(1:length(generation_vectors_GB["Wind Offshore"]), generation_vectors_GB["Wind Offshore"], label = "Offshore Wind", color = :green)
Plots.plot!(1:length(generation_vectors_GB["Solar"]), generation_vectors_GB["Solar"], label = "Solar", color = :orange)
Plots.plot!(1:length(generation_vectors_GB["Fossil Gas"]), generation_vectors_GB["Fossil Gas"], label = "Fossil Gas", color = :red)
Plots.plot!(1:length(generation_vectors_GB["Fossil Oil"]), generation_vectors_GB["Fossil Oil"], label = "Fossil Oil", color = :black)



## Load data processing
load   = CSV.read(joinpath(DATA_DIR, "load.csv"), DataFrame)

load_IE = Dict{String,Any}()
load_GB = Dict{String,Any}()
count_IE = 0
count_GB = 0
for t in 1:length(load[:,1])
    if load[t,2] == "IE"
        timestamp_str = string(load[t,1])
        count_IE += 1
        load_IE["$count_IE"] = Dict{String,Any}()
        load_IE["$count_IE"]["day"] = timestamp_str[9:10]
        load_IE["$count_IE"]["month"] = timestamp_str[6:7]
        load_IE["$count_IE"]["year"] = timestamp_str[1:4]
        load_IE["$count_IE"]["hour"] = timestamp_str[12:13]
        load_IE["$count_IE"]["minute"] = timestamp_str[15:16]
        load_IE["$count_IE"]["second"] = timestamp_str[18:19]
        load_IE["$count_IE"]["load"] = load[t,3]
    elseif load[t,2] == "GB"
        timestamp_str = string(load[t,1])
        count_GB += 1
        load_GB["$count_GB"] = Dict{String,Any}()
        load_GB["$count_GB"]["day"] = timestamp_str[9:10]
        load_GB["$count_GB"]["month"] = timestamp_str[6:7]
        load_GB["$count_GB"]["year"] = timestamp_str[1:4]
        load_GB["$count_GB"]["hour"] = timestamp_str[12:13]
        load_GB["$count_GB"]["minute"] = timestamp_str[15:16]
        load_GB["$count_GB"]["second"] = timestamp_str[18:19]
        load_GB["$count_GB"]["load"] = load[t,3]
    end
end

unique(load_IE["$i"]["minute"] for i in 1:length(load_IE))
load_IE["1466"]
load_GB["1466"]

# Find the missing 30-minute timesteps in load_IE (expected: one point every 30 min for the whole month)
timestamps_load_IE = Set(DateTime(parse(Int, load_IE["$i"]["year"]), parse(Int, load_IE["$i"]["month"]), parse(Int, load_IE["$i"]["day"]),parse(Int, load_IE["$i"]["hour"]), parse(Int, load_IE["$i"]["minute"])) for i in 1:length(load_IE))
first_ts = floor(minimum(timestamps_load_IE), Month)
last_ts  = ceil(maximum(timestamps_load_IE), Month) - Minute(30)
missing_timesteps_IE = [t for t in first_ts:Minute(30):last_ts if !(t in timestamps_load_IE)]
missing_hours_IE = unique(floor.(missing_timesteps_IE, Hour))

## Electricity prices data processing
prices = CSV.read(joinpath(DATA_DIR, "prices.csv"), DataFrame)
el_price_IE = Dict{String,Any}()
el_price_GB = Dict{String,Any}()
count_IE = 0
count_GB = 0
for t in 1:length(prices[:,1])
    if prices[t,2] == "IE_SEM"
        count_IE += 1
        timestamp_str = string(prices[t,1])
        el_price_IE["$count_IE"] = Dict{String,Any}()
        el_price_IE["$count_IE"]["day"] = timestamp_str[9:10]
        el_price_IE["$count_IE"]["month"] = timestamp_str[6:7]
        el_price_IE["$count_IE"]["year"] = timestamp_str[1:4]
        el_price_IE["$count_IE"]["hour"] = timestamp_str[12:13]
        el_price_IE["$count_IE"]["minute"] = timestamp_str[15:16]
        el_price_IE["$count_IE"]["second"] = timestamp_str[18:19]
        el_price_IE["$count_IE"]["price"] = prices[t,3]
    elseif prices[t,2] == "GB"
        count_GB += 1
        timestamp_str = string(prices[t,1])
        el_price_GB["$count_GB"] = Dict{String,Any}()
        el_price_GB["$count_GB"]["day"] = timestamp_str[9:10]
        el_price_GB["$count_GB"]["month"] = timestamp_str[6:7]
        el_price_GB["$count_GB"]["year"] = timestamp_str[1:4]
        el_price_GB["$count_GB"]["hour"] = timestamp_str[12:13]
        el_price_GB["$count_GB"]["minute"] = timestamp_str[15:16]
        el_price_GB["$count_GB"]["second"] = timestamp_str[18:19]
        el_price_GB["$count_GB"]["price"] = prices[t,3]
    end
end
elec_price_IE = [el_price_IE["$t"]["price"] for t in 1:length(el_price_IE)]
Plots.plot(1:length(el_price_IE), elec_price_IE, label = "IE", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Price [€/MWh]",xticks = 1:(24*7):length(el_price_IE))

unique(el_price_IE["$i"]["hour"] for i in 1:length(el_price_IE))
unique(el_price_IE["$i"]["minute"] for i in 1:length(el_price_IE))
unique(el_price_IE["$i"]["day"] for i in 1:length(el_price_IE))
unique(el_price_IE["$i"]["month"] for i in 1:length(el_price_IE))
unique(el_price_IE["$i"]["year"] for i in 1:length(el_price_IE))
unique(el_price_IE["$i"]["second"] for i in 1:length(el_price_IE))

unique(el_price_GB["$i"]["minute"] for i in 1:length(el_price_GB))

elec_prices_IE_plot = [el_price_IE["$t"]["price"] for t in 1:length(gen_hourly_IE_onw)]

plot()
plot!()

p = Plots.plot(
    1:length(gen_hourly_IE_onw), gen_hourly_IE_onw,
    xlabel = "Timestep [-]",
    ylabel = "Onshore wind generation [MWh]",
    label = "Onshore Wind",
    linewidth = 2,
)


gen_hourly_IE_onw   = [generation_vectors_IE["Wind Onshore"][t] for t in 1:length(generation_vectors_IE["Wind Onshore"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_pv    = [generation_vectors_IE["Solar"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_fg    = [generation_vectors_IE["Fossil Gas"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_fo    = [generation_vectors_IE["Fossil Oil"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_fp    = [generation_vectors_IE["Fossil Peat"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
gen_hourly_IE_hydro = [generation_vectors_IE["Hydro Run-of-river and poundage"][t] for t in 1:length(generation_vectors_IE["Fossil Peat"]) if gen_IE["$t"]["minute"] == "00"]
total_hourly = [gen_hourly_IE_onw[t] + gen_hourly_IE_pv[t] + gen_hourly_IE_fg[t] + gen_hourly_IE_fo[t] + gen_hourly_IE_fp[t] + gen_hourly_IE_hydro[t] for t in 1:length(gen_hourly_IE_onw)]

gen = Plots.plot(1:length( gen_hourly_IE_onw), gen_hourly_IE_onw  , label = "Onshore Wind", color = :blue, legend = :outertopright, xlabel = "Timestep [-]", ylabel = "Generation [MW]",xticks = 1:(100):length(generation_vectors_IE["Wind Onshore"]))
Plots.plot!(gen,1:length(gen_hourly_IE_onw), gen_hourly_IE_pv   , label = "Solar", color = :orange)
Plots.plot!(gen,1:length(gen_hourly_IE_onw), gen_hourly_IE_fg   , label = "Fossil Gas", color = :red)
Plots.plot!(gen,1:length(gen_hourly_IE_onw), gen_hourly_IE_fo   , label = "Fossil Oil", color = :black)
Plots.plot!(gen,1:length(gen_hourly_IE_onw), gen_hourly_IE_fp   , label = "Fossil Peat", color = :brown)
Plots.plot!(gen,1:length(gen_hourly_IE_onw), gen_hourly_IE_hydro, label = "Hydro", color = :cyan)
Plots.plot!(gen,1:length(gen_hourly_IE_onw), total_hourly, label = "Total", color = :black, linestyle = :dash)

save(joinpath(dirname(@__DIR__),"figures","Gen_IE_hourly.pdf"), gen)

prices = Plots.plot(
    1:length(elec_prices_IE_plot), elec_prices_IE_plot,xticks = 1:(100):length(generation_vectors_IE["Wind Onshore"]),
    ylabel = "Electricity price [€/MWh]",
    label = "Electricity price",
    linewidth = 1,
    color = :red,
    #,
    #xticks = 1:(48*7):length(generation_vectors_IE["Wind Onshore"])
)
save(joinpath(dirname(@__DIR__),"figures","Prices_IE_hourly.pdf"), prices)

