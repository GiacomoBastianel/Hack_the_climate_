

function reduce_loads(data, load_factor)
    for (load_id, load) in data["load"]
        # load["pd"] *= load_factor
        load["qd"] *= load_factor
    end
end

function modify_selected_gen(data, gen_ids, new_qmax)
    for g_id in gen_ids
        if haskey(data["gen"], g_id)
            data["gen"][g_id]["qmax"] = new_qmax
            data["gen"][g_id]["qmin"] = -new_qmax
        else
            println("Generator ID $g_id not found in the grid data.")
        end
    end
end

function get_top_10_min_reactive_power_gen(IE_grid_opf, res_opf, start_hour, end_hour)
    # Collect the reactive power generation values for each generator
    reactive_power_gen = [Dict{String,Any}() for t in start_hour:end_hour]
    for t in start_hour:end_hour
        for (g_id, g) in res_opf["$t"]["solution"]["gen"]
            reactive_power_gen[t - start_hour + 1][g_id] = g["qg"]
        end
    end
    # Find the top 10 minimum reactive power generation across all generators and which generators they belong to
    min_reactive_power_gen = Dict{String,Any}()
    for (g_id, g) in IE_grid_opf["gen"]
        min_qg = minimum([reactive_power_gen[t - start_hour + 1][g_id] for t in start_hour:end_hour])
        min_reactive_power_gen[g_id] = min_qg
    end
    sorted_min_reactive_power_gen = sort(collect(min_reactive_power_gen), by = x -> x[2])
    return sorted_min_reactive_power_gen[1:10]
end

## Get the top 10 minimum reactive power generation
top_10_min_reactive_power_gen = get_top_10_min_reactive_power_gen(IE_grid_opf, res_opf, start_hour, end_hour)

for (g_id, g) in top_10_min_reactive_power_gen
    qmin = IE_grid_opf["gen"][g_id]["qmin"]
    qmax = IE_grid_opf["gen"][g_id]["qmax"]
    zone = IE_grid_opf["gen"][g_id]["zone"]
    println("Generator $g_id: min reactive power generation = $(g), qmin = $(qmin), qmax = $(qmax), zone = $(zone)")
end
## Gen bus IDs for the top 10 minimum reactive power generation
top_10_min_reactive_power_gen_buses = [IE_grid_opf["gen"][g_id]["gen_bus"] for (g_id, g) in top_10_min_reactive_power_gen]
## Load IDs for the top 10 minimum reactive power generation buses
top_10_min_reactive_power_gen_loads = [load_id for (load_id, load) in IE_grid_opf["load"] if load["load_bus"] in top_10_min_reactive_power_gen_buses]

## Compare the results with the reactive power with the qmax of the generators from IE_grid_opf
##


## Function to sort parameters based on the selected component (gen, bus, branch) and the selected parameter (e.g., qmax, pd, br_r)
function sort_parameters(data, component::String, parameter::String)
    # ONly include the id and the parameter value in the output
    param_values = [(id, comp[parameter]) for (id, comp) in data[component]]
    sorted_params = sort(param_values, by = x -> x[2])
    return sorted_params
end
# Test the function with the generator data and the "qmax" parameter
# test_sort_parameters = sort_parameters(res_opf["data"], "branch", "b_fr")