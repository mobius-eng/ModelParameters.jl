__precompile__()
module ModelParameters

using KeywordDispatch


include("Units.jl")

using ModelParameters.Units

export regconv, toSI, fromSI, get_toSI_converter, get_fromSI_converter

export AbstractParameter, ParameterBase
export Parameter, ParameterOptions, ParameterContainer, PerturbedParameter
export ParameterBroadcaster
export id, name, description, transformer, value, transform, units
export setid!, setname!, setdescription!, settransformer!, setvalue!
export traverse, transform
export perturbation, setperturbation!, perturb!
export selection, setselection!
export broadcastsize, setbroadcastsize!
export parameter

parameter = KeywordDispatchFunction()


"""
Abstract Parameter: all parameters must have it as a parent
"""
abstract AbstractParameter

"""
Base type for all parameters: provides shared fields:
	- `id` (`Symbol`) identification of the parameter
	- `name` (`AbstractString`) printable name
	- `decription` (`AbstractString`) detailed description of the parameter
	- `transformer` (`Function`) parameter value transformer to get target
		value/object
"""
type ParameterBase
    id :: Symbol
    name :: AbstractString
    description :: AbstractString
    transformer
	function ParameterBase(; id = :id, name = string(id),
							description = "", transformer = identity,
							more...)
		new(id, name, description, transformer)
	end
end

"""
Returns the name of the parameter

This function is required to implement a new parameter
"""
name(p :: ParameterBase) = p.name

"""
Sets the new name of the parameter

This function is required to implement a new parameter
"""
setname!(p :: ParameterBase, newname) = p.name = newname

"""
Returns the identification of the parameter (symbol)

This function is required to implement a new parameter
"""
id(p :: ParameterBase) = p.id

"""
Sets the new id to a parameter

This function is required to implement a new parameter
"""
setid!(p :: ParameterBase, newid) = p.id = newid

"""
Returns an extended description of the parameter

This function is required to implement a new parameter
"""
description(p :: ParameterBase) = p.description

"""
Sets the new description to a parameter

This function is required to implement a new parameter
"""
setdescription!(p :: ParameterBase, newdesc) = p.description = newdesc

"""
Returns the transformer of the value associated with the parameter

This function is required to implement a new parameter
"""
transformer(p :: ParameterBase) = p.transformer

"""
Sets new tranformer to a parameter

This function is required to implement a new parameter
"""
settransformer!(p :: ParameterBase, f) = p.transformer = f

"""
Returns actual useful value out of parameter.

It usually combines `value` and `transformer` to construct actual value

This function is required to implement a new parameter
"""
transform(p :: AbstractParameter) = transformer(p)(value(p))

"""
Creates an implementation of basic generic functions of parameters:

`name`, `setname!`, `id`, `setid!`, `description`, `setdescription!`,
`transformer` and `setransformer!`

by passing the call to the corresponding function of the `field` of
the parameter.

For example,

	@parambasics(NewKindParameter, basic)

Will result for `name` to become:

	name(p :: NewKindParameter) = name(p.basic)
"""
macro parambasics(param, field)
	quote
		global name(p :: $param) = name(p.$field)
		global setname!(p :: $param, newname) = setname!(p.$field, newname)
		global id(p :: $param) = id(p.$field)
		global setid!(p :: $param, newid) = setid!(p.$field, newid)
		global description(p :: $param) = description(p.$field)
		global setdescription!(p :: $param, d) = setdescription!(p.$field, d)
		global transformer(p :: $param) = transformer(p.$field)
		global settransformer!(p :: $param, f) = settransformer!(p.$field, f)
	end
end

"""
Single Parameter
"""
type Parameter <: AbstractParameter
    base :: ParameterBase
    value :: Any
    units :: AbstractString
    function Parameter(; value = 0, units = "-", kwargs...)
        new(ParameterBase(;kwargs...), value, units)
    end
end

@parambasics(Parameter, base)

"""
Returns the "value" associated with a parameter.

This function is required to implement a new parameter
"""
value(p :: Parameter) = p.value

"""
Sets a new value with the parameter

This function is required to implement a new parameter
"""
setvalue!(p :: Parameter, newvalue) = p.value = newvalue

"""
Returns units of measure of the parameter

This function is NOT required to implement a new parameter.

The single value parameter should implement it
"""
units( p :: Parameter) = p.units

"""
Sets new units of measure of the parameter

This function is NOT required to implement a new parameter.

The single value parameter should implement it
"""
setunits!(p :: Parameter, newunits) = p.units = newunits

"""
Applies function `f` to parameter. Convention used: f(x) must return Bool.
If f(x) is true: keep applying it to subparameters of `p` if `p` is some
kind of container parameter of other parameters.
"""
traverse(p :: Parameter, f) = f(p)

"""
Container of other parameters
"""
type ParameterContainer <: AbstractParameter
    base :: ParameterBase
    children :: Vector{AbstractParameter}
    function ParameterContainer(;
			children = [],
			transformer = (; kw...) -> kw,
			kwargs...)
		updatedargs = [(:transformer, transformer), kwargs...]
		base = ParameterBase(; updatedargs...)
        new(base, children)
    end
end

@parambasics(ParameterContainer, base)

value(p :: ParameterContainer) =
	Dict{Symbol, Any}(map(c -> (id(c), value(c)), p.children))

function Base.get(p :: ParameterContainer, key)
	for child in p.children
		if id(child) === key
			return child
		end
	end
	throw(KeyError(key))
end

function Base.get(p :: ParameterContainer, key, default)
	for child in p.children
		if id(child) === key
			return child
		end
	end
	return default
end

function Base.getindex(p :: ParameterContainer, key)
	return get(p, key)
end

function Base.setindex!(p :: ParameterContainer, val, key)
	c = p.children
	cnew = map(child -> id(child)=== key? val : child, c)
	p.children = cnew
end

function setvalue!(p :: ParameterContainer, newvalue)
	for (k,v) in newvalue
		setvalue!(get(p, k), v)
	end
end

"""
Transform for container is slightly different: the transformer is assumed to
take keyword arguments
"""
function transform(p :: ParameterContainer)
	args = (map(c -> (id(c), transform(c)), p.children))
	transformer(p)(;args...)
end

function traverse(p :: ParameterContainer, f)
	if f(p)
		for child in p.children
			traverse(child, f)
		end
	end
end

"""
Selection between alternative options
"""
type ParameterOptions <: AbstractParameter
    base :: ParameterContainer
    selection :: Symbol
    function ParameterOptions(; transformer = identity, selection = 1, kwargs...)
        new(ParameterContainer(;[(:transformer, transformer), kwargs...]...), selection)
    end
end

@parambasics(ParameterOptions, base)

selection(p :: ParameterOptions) = p.selection

function setselection!(p :: ParameterOptions, s)
	let g = gensym()
		if !(get(p.base, s, g) === g)
			p.selection = s
		else
			throw(KeyError(s))
		end
	end
end

value(p :: ParameterOptions) = value(p.base)[p.selection]

function setvalue!(p :: ParameterOptions, newvalue)
	vals = value(p.base)
	vals[p.selection] = newvalue
	setvalue!(p.base, vals)
end

function transform(p :: ParameterOptions)
	selected = get(p.base, p.selection)
	transformer(p)(transform(selected))
end

function traverse(p :: ParameterOptions, f)
	if f(p)
		tranverse(p.base, f)
	end
end

type PerturbedParameter <: AbstractParameter
	parameter :: Parameter
	perturbation :: Float64
	function PerturbedParameter(p :: Parameter, v :: Float64)
		new(p, v)
	end
	function PerturbedParameter(; perturbation = 0.0, kwargs...)
		new(Parameter(; kwargs...), perturbation)
	end
end

@parambasics(PerturbedParameter, parameter)

value(p :: PerturbedParameter) = value(p.parameter)
setvalue!(p :: PerturbedParameter, newval) = setvalue!(p.parameter, newval)

"""
Returns perturbation of the parameter. If parameter does not have a
perturbation usefully associated with it, returns 0.0
"""
perturbation(p :: AbstractParameter) = 0.0
perturbation(p :: PerturbedParameter) = p.perturbation
setperturbation!(p :: PerturbedParameter, val) = p.perturbation = val

function perturb!(p :: PerturbedParameter, val :: Float64)
	setperturbation!(p, val)
	return p
end

function perturb!(p :: Parameter, val :: Float64)
	return PerturbedParameter(p, val)
end

function perturb!{T <: Any}(p :: ParameterContainer, val :: Dict{Symbol, T})
	notfound = gensym()
	for (k,v) in val
		if !(get(p, k, notfound) === notfound)
			p[k] = perturb!(p[k], v)
		else
			warn("Parameter $k not found in $p")
		end
	end
	return p
end

function perturb!{T <: Any}(p :: ParameterOptions, val :: Dict{Symbol, T})
	p.base = perturb!(p.base, val)
	return p
end

function transform(p :: PerturbedParameter)
	transform(p.parameter) * (1.0 + (2.0 * rand() - 1.0) * p.perturbation)
end

function traverse(p :: PerturbedParameter, f)
	if f(p)
		traverse(p.parameter, f)
	end
end


type ParameterBroadcaster <: AbstractParameter
	base :: ParameterContainer
	size :: Parameter
	function ParameterBroadcaster(;
			size = 1,
			size_name = "Number of items",
			size_id = :broadcastsize,
			size_desc = "Number of items to be instantiated",
			kwargs...)
		p = parameter(name = size_name,
			id = size_id,
			value = size,
			description = size_desc)
		new(ParameterContainer(;kwargs...), p)
	end
end

@parambasics(ParameterBroadcaster, base)

function transform(p :: ParameterBroadcaster)
	n = broadcastsize(p)
	map(i -> transform(p.base), 1:n)
end

function value(p :: ParameterBroadcaster)
	d = value(p.base)
	d[id(p.size)] = value(p.size)
	return d
end

function setvalue!(p :: ParameterBroadcaster, v)
	newsize = pop!(v, id(p.size), value(p.size))
	setvalue!(p.size, newsize)
	setvalue!(p.base, v)
end

Base.get(p :: ParameterBroadcaster, key) =
	key === id(p.size)? p.size : get(p.base, key)

Base.get(p :: ParameterBroadcaster, key, default) =
	key === id(p.size)? p.size : get(p.base, key, default)

function Base.getindex(p :: ParameterBroadcaster, key)
	if key === id(p.size)
		p.size
	else
		p.base[key]
	end
end

function Base.setindex!(p :: ParameterBroadcaster, val, key)
	if key === id(p.size)
		p.size = val
	else
		p.base[key] = val
	end
end

function perturb!{T <: Any}(p :: ParameterBroadcaster, val :: Dict{Symbol, T})
	p.base = perturb!(p.base, val)
	return p
end

broadcastsize(p :: ParameterBroadcaster) = value(p.size)

setbroadcastsize!(p :: ParameterBroadcaster, n) =
	setvalue!(p.size, n)

@defkwspec parameter [:value] (args) begin
	Parameter(; args...)
end

macroexpand(:(@defkwspec parameter [:value] (args) begin
	Parameter(; args...)
end))

@defkwspec parameter [:children] (args) begin
	ParameterContainer(; args...)
end


@defkwspec parameter [:children :selection] (args) begin
	ParameterOptions(; args...)
end

@defkwspec parameter [:value :perturbation] (args) begin
	PerturbedParameter(; args...)
end

@defkwspec parameter [:children :size] (args) begin
	ParameterBroadcaster(; args...)
end

# include("YAMLParameters.jl")

# p1 = Parameter(id = :mass, value = 1.0, units = "g")

# p1 = PerturbedParameter(id = :mass, value = 1.0, units = "g", perturbation = 0.1)
#
# p1
#
# transform(p1)

# p2 = Parameter(id = :speed, value = 36.0, units = "km/h")
#
#
# pc = ParameterContainer(id = :momentum, children = [p1, p2])
#
# p3 = Parameter(id = :temperature, value = 20.0, units = "°C")
#
# po = ParameterOptions(id = :physics, options = [pc, p3])
# po.selection = 2
#
# transform(po)

# file = "/home/alexey/.julia/v0.4/Parameters/test/base.yaml"
# x = load_yaml_config(file)
# y = load_yaml_config(file, Dict(:example => vec -> Dict(vec), :k => x -> x * 1e7))
# transform(y)

# parameter(
# 	id = :container,
# 	name = "Container",
# 	children = [
# 		parameter(id = :a, value = 1.0),
# 		parameter(id = :b, value = 2.0, units = "cm"),
# 		parameter(id = :options, options =[
# 			parameter(id = :option1, value = 1.0),
# 			parameter(id = :option2, value = 2.0)])])



end # module
