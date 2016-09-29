# __precompile__()
# module YAMLParameters

using YAML
# using Parameters

export paramyaml, add_paramyaml_specializer, load_yaml_config

"""
Convert string to symbol using conversionmap dictionary
If not found in the dictionary - intern symbol from the string
"""
function paramid{T <: AbstractString}(
        s :: AbstractString,
        conversionmap :: Dict{T, Symbol} = Dict{AbstractString, Symbol}())
    get(conversionmap, s, symbol(s))
end

"""
Gets name, id and description from the dictionary
"""
function nameiddesc(dict :: Dict)
    name = get(dict, "name", :notfound)
    id = get(dict, "id",:notfound)
    if name === :notfound && id === :notfound
        error("Either name of id must be provided!")
    elseif name === :notfound
        name = id
    elseif id === :notfound
        id = name
    end
    id = symbol(id)
    (name, id, get(dict, "description", ""))
end

"""
Converts dictionary to Parameter.
Dictionary must contain "value" key
"""
function parameter_yaml(m :: Dict)
    (name, id, description) = nameiddesc(m)
    value = m["value"]
    units = get(m, "units", "-")
    Parameter(
        name = name,
        id = id,
        value = value,
        description = description,
        units = units)
end

"""
Converts dictionary (with "children" key) to ParameterContainer
"""
function container_yaml(m :: Dict)
    (name, id, desc) = nameiddesc(m)
    children = m["children"]
    ParameterContainer(
        name = name,
        id = id,
        description = desc,
        children = map(paramyaml, children)
    )
end

"""
Converts dictionary (with "options" key) to ParameterOptions
"""
function options_yaml(m :: Dict)
    (name, id, desc) = nameiddesc(m)
    options = m["options"]
    selection = get(m, "selection", 1)
    ParameterOptions(
        name = name,
        id = id,
        description = desc,
        options = map(paramyaml,options),
        selection = selection
    )
end

"""
Converts dictionary (with "value" and "perturbation" keys) to
PerturbedParameter
"""
function perturbed_yaml(m :: Dict)
    (name, id, desc) = nameiddesc(m)
    value = m["value"]
    perturbation = m["perturbation"]
    units = get(m, "units", "-")
    PerturbedParameter(
        name = name,
        id = id,
        value = value,
        units = units,
        perturbation = perturbation
    )
end

"""
Dispatch dictionary for conversion
Each entry must be (default, Dict())
where Dict may contain further specializing arguments
"""
const paramyaml_conversions = Dict()

"""
Add new specializer for converting dictionary to <: AbstractParameter
"""
function add_paramyaml_specializer(
        f :: Function,
        names,
        dict = paramyaml_conversions)
    if length(names) == 1
        dict[names[1]] = (f, Dict())
    else
        if !haskey(dict, names[1])
            error("Overspecializing")
        else
            default, subdict = dict[names[1]]
            add_paramyaml_specializer(f, names[2:end], subdict)
        end
    end
    :done
end

begin
    add_paramyaml_specializer(parameter_yaml, ["value"])
    add_paramyaml_specializer(container_yaml, ["children"])
    add_paramyaml_specializer(options_yaml, ["options"])
    add_paramyaml_specializer(perturbed_yaml, ["value", "perturbation"])
end

"""
Construct parameter from dictionary `m` obtained from loading YAML file.

YAML files generally cannot contain parameter transformers. In which case,
a default transformer is used (usually `identity`). Otherwise, transformers
can be supplied by `trnsformers` parameter.

Optional dict is used to find the correct correspondence of `m` to a
particular parameter type. See `add_paramyaml_specializer`
"""
function paramyaml(m :: Dict, dict = paramyaml_conversions, default = identity)
    for key in keys(dict)
        if haskey(m, key)
            subdefault, subdict = dict[key]
            return paramyaml(m, subdict, subdefault)
        end
    end
    # didn't find a key: call default
    default(m)
end

function paramyaml(m :: Dict, transformers :: Dict{Symbol, Function})
    p = paramyaml(m)
    traverse(p, p ->
        begin
            if haskey(transformers, id(p))
                settransformer!(p, transformers[id(p)])
            end
            return true
        end)
    p
end

"""
Construct parameter from YAML config file
"""
function load_yaml_config(filename,
            transformers :: Dict{Symbol, Function} = Dict{Symbol, Function}())
    data = YAML.load_file(filename)
    paramyaml(data, transformers)
end


function update_param_from_config(p :: AbstractParameter, filename)
    data = YAML.load_file(filename)

end
