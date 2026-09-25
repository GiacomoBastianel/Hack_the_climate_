# Script to plot the Irish electricity grid on a map
using JSON
using Plots

# Load the grid data
const DATA_DIR = joinpath(dirname(@__DIR__), "data")
grid_file = joinpath(DATA_DIR, "IE_grid.json")
grid_data = JSON.parsefile(grid_file)

# Extract Irish buses (zone == "IE")
IE_buses = Dict()
for (bus_id, bus_info) in grid_data["bus"]
    if bus_info["zone"] == "IE" || bus_info["zone"] == "NI"
        IE_buses[bus_id] = bus_info
    end
end

println("Found $(length(IE_buses)) buses in IE grid")

# Extract coordinates for Irish buses
bus_lats = [bus["lat"] for (id, bus) in IE_buses]
bus_lons = [bus["lon"] for (id, bus) in IE_buses]
bus_names = [bus["name"] for (id, bus) in IE_buses]
bus_ids = collect(keys(IE_buses))

# Extract Irish branches (transmission lines connecting IE buses)
IE_branches = []
for (branch_id, branch_info) in grid_data["branch"]
    f_bus = string(branch_info["f_bus"])  # from bus
    t_bus = string(branch_info["t_bus"])  # to bus

    # Check if both buses are in Ireland
    if haskey(IE_buses, f_bus) && haskey(IE_buses, t_bus)
        push!(IE_branches, (f_bus, t_bus, branch_info))
    end
end

println("Found $(length(IE_branches)) transmission lines in IE grid")

# Create the plot
p = Plots.plot(
    xlabel = "Longitude",
    ylabel = "Latitude",
    title = "Irish Electricity Grid",
    legend = false,
    aspect_ratio = :equal,
    size = (800, 800)
)

# Plot transmission lines first (so they appear behind the buses)
for (f_bus, t_bus, branch_info) in IE_branches
    f_lat = IE_buses[f_bus]["lat"]
    f_lon = IE_buses[f_bus]["lon"]
    t_lat = IE_buses[t_bus]["lat"]
    t_lon = IE_buses[t_bus]["lon"]

    Plots.plot!(p, [f_lon, t_lon], [f_lat, t_lat],
          color = :gray,
          alpha = 0.5,
          linewidth = 1)
end

# Plot buses as scatter points
Plots.scatter!(p, bus_lons, bus_lats,
         color = :red,
         markersize = 4,
         markerstrokewidth = 0,
         label = "Substations")

# Save the plot
output_file = joinpath(dirname(@__DIR__), "figures", "IE_grid_map.pdf")
mkpath(dirname(output_file))
savefig(p, output_file)
println("Grid map saved to: $output_file")

# Also display the plot
display(p)



# Print some statistics
println("\nGrid Statistics:")
println("  Latitude range: $(minimum(bus_lats)) to $(maximum(bus_lats))")
println("  Longitude range: $(minimum(bus_lons)) to $(maximum(bus_lons))")
println("  Number of substations: $(length(IE_buses))")
println("  Number of transmission lines: $(length(IE_branches))")

# Optionally, color by voltage level
voltage_levels = [bus["base_kv"] for (id, bus) in IE_buses]
unique_voltages = sort(unique(voltage_levels))
println("  Voltage levels (kV): $(unique_voltages)")

# Create a second plot colored by voltage level
p2 = Plots.plot(
    xlabel = "Longitude",
    ylabel = "Latitude",
    title = "Irish Electricity Grid - Colored by Voltage Level",
    aspect_ratio = :equal,
    size = (800, 800)
)

# Plot transmission lines
for (f_bus, t_bus, branch_info) in IE_branches
    f_lat = IE_buses[f_bus]["lat"]
    f_lon = IE_buses[f_bus]["lon"]
    t_lat = IE_buses[t_bus]["lat"]
    t_lon = IE_buses[t_bus]["lon"]

    Plots.plot!(p2, [f_lon, t_lon], [f_lat, t_lat],
          color = :gray,
          alpha = 0.3,
          linewidth = 1,
          label = "")
end

# Plot buses colored by voltage level
colors_map = Dict(110 => :blue, 220 => :orange, 400 => :red)
for voltage in unique_voltages
    voltage_buses_lats = []
    voltage_buses_lons = []

    for (id, bus) in IE_buses
        if bus["base_kv"] == voltage
            push!(voltage_buses_lats, bus["lat"])
            push!(voltage_buses_lons, bus["lon"])
        end
    end

    color = get(colors_map, voltage, :green)
    Plots.scatter!(p2, voltage_buses_lons, voltage_buses_lats,
             color = color,
             markersize = 5,
             markerstrokewidth = 0,
             label = "$(voltage) kV")
end

# Save the voltage-colored plot
output_file2 = joinpath(dirname(@__DIR__), "figures", "IE_grid_map_voltage.pdf")
savefig(p2, output_file2)
println("Voltage-colored grid map saved to: $output_file2")

display(p2)

for (b_id, b) in IE_grid["bus"]
    if b["base_kv"] == 275 && b["lon"] > -7 && b["lon"] < -6 && b["lat"] < 54 && b["lat"] > 53
        println("Bus ID: $b_id, Lat: $(b["lat"]), Lon: $(b["lon"])")
    end
end