__precompile__()
module Units

export regconv, toSI, fromSI, get_toSI_converter, get_fromSI_converter

"""
`Conversion` is the container for forward and backward conversion of units
of measure (`toSI` and `fromSI` fields)
"""
immutable Conversion
	toSI :: Function
	fromSI :: Function
end

"""
Dictionary of units conversion
"""
const conversions = Dict{AbstractString, Conversion}()

"""
Registers units conversion to and from SI units
"""
function regconv(units :: AbstractString, toSI, fromSI)
	conversions[units] = Conversion(toSI, fromSI)
	:done
end

function regconv{T <: AbstractString}(units :: Vector{T}, toSI, fromSI)
	for unit in units
		regconv(unit, toSI, fromSI)
	end
end

"""
Converts `value` of `units` of measure to SI units
"""
toSI(value, units :: AbstractString) = conversions[units].toSI(value)

"""
Converts `value` from SI units of measure to `units`
"""
fromSI(value, units :: AbstractString) = conversions[units].fromSI(value)

"""
Produces the function that converts the value from requested `units`
to SI units.

The `units` must be register prior the use of this function
(see `regconv` function)
"""
function get_toSI_converter(units, default = identity)
	c = get(conversions, units, :null)
	if c === :null
		return default
	else
		return c.toSI
	end
end

"""
Produces the function that converts the value from SI `units` to
requested units.

The `units` must be register prior the use of this function
(see `regconv` function)
"""
function get_fromSI_converter(units, default = identity)
	c = get(conversions, units, :null)
	if c === :null
		return default
	else
		return c.fromSI
	end
end

# Registering standard/useful conversions
# Length
regconv("m", identity, identity)
regconv("cm", x -> x / 100, x -> x * 100)
regconv("mm", x -> x / 1000, x -> x * 1000)
regconv("um", x -> x / 1e6, x -> x * 1e6)
regconv("μm", x -> x / 1e6, x -> x * 1e6)
regconv("km", x -> x * 1000, x -> x / 1000)
regconv("nm", x -> x / 1e9, x -> x * 1e9)

# Mass
regconv("kg", identity, identity)
regconv("g", x -> x / 1000, x -> x * 1000)
regconv(["t", "tonne"], x -> x * 1000, x -> x / 1000)

# Time
regconv(["s", "sec", "second", "seconds"], identity, identity)
regconv(["h", "hour", "hours", "hr", "hrs"], x -> x * 3600, x -> x / 3600)
regconv(["min", "minute", "minutes"], x -> x * 60, x -> x / 60)
regconv(["day", "d", "days"], x -> 24 * 3600, x -> x / 24 / 3600)

# Velocity
regconv(["m/s"], identity, identity)
regconv(["km/h", "kmph"], x -> x * 10 / 36, x -> x * 36 / 10)
regconv(["L/m2.h", "L/(m2.h)", "L/(m^2 h)", "L/(m^2.h)"],
	x -> x / 1000 / 3600,
	x -> x * 1000 * 3600)

# Diffusivity
regconv(["m2/s", "m^2/s"], identity, identity)
regconv(["cm2/s", "cm^2/s"], x -> x / 10000, x -> x * 10000)

# Area
regconv(["m2", "m^2"], identity, identity)
regconv(["cm2", "cm^2"], x -> x / 10000, x -> x * 10000)

# Volume
regconv(["m3", "m^3"], identity, identity)
regconv(["L", "l"], x -> x / 1000, x -> x * 1000)
regconv(["ml", "mL", "cm3", "cm^3"], x -> x / 1e6, x -> x * 1e6)

# Temperature
regconv("K", identity, identity)
regconv(["°C", "C"], x -> x + 273.15, x -> x - 273.15)

end
