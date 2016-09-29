module ModelParametersTest

using Base.Test
using ModelParameters

const x = parameter(name = "A", id = :a, value = 10)

@test value(x) == 10
@test name(x) == "A"
@test id(x) === :a
@test units(x) == "-"
@test description(x) == ""
@test transformer(x) === identity

@test transform(x) == 10


const mass = parameter(
	name = "Mass",
	id = :mass,
	value = 300.0,
	units = "g",
	transformer = x -> x / 1000.0)

@test transform(mass) ≈ 0.3

const children = [
	parameter(
		name = "Temperature",
		id = :temperature,
		value = 30.0,
		units = "°C",
		transformer = x -> x + 273.15),
	parameter(
		name = "Pressure",
		id = :pressure,
		value = 2.0,
		units = "bar",
		transformer = x -> x * 1e5)]

const idealgas = parameter(
	name = "Ideal gas",
	id = :idealgas,
	children = children)

@test id(idealgas) === :idealgas
@test value(idealgas) == Dict(:temperature => 30.0, :pressure => 2.0)

setvalue!(idealgas, Dict(:pressure => 1.5))

@test value(get(idealgas, :pressure)) == 1.5


let expected = Dict(:pressure => 1.5 * 1e5, :temperature => 30.0 + 273.15)
	for (k,v) in transform(idealgas)
		@test_approx_eq v expected[k]
	end
end

const temps = parameter(
	name = "Temperature",
	id = :temperature,
	children = [
		parameter(
			name = "T (°C)",
			id = :celcius,
			value = 30.0,
			units = "°C",
			transformer = x -> x + 273.15),
		parameter(
			name = "T (K)",
			id = :kelvin,
			value = 293.15,
			units = "K")],
	selection = :celcius)

@test typeof(temps) == ParameterOptions

@test value(temps) == 30.0

# transform(temps)

@test transform(temps) ≈ 303.15

@test_throws KeyError setselection!(temps, :blah)

setselection!(temps, :kelvin)

@test value(temps) ≈ 293.15

@test transform(temps) ≈ 293.15

const velocity = parameter(
	name = "Velocity",
	id = :velocity,
	value = 3.0,
	units = "m/s",
	perturbation = 0.1)

@test value(velocity) == 3.0

let err = 0.0, larger = 0, less = 0
	for i=1:10000
		let v = transform(velocity)
			if v > 3.0
				larger += 1
			else
				less += 1
			end
			err += abs(transform(velocity) - 3.0)
		end
	end
	@test 1450.0 < err < 1650.0
	@test 4500 < less < 5500
	@test 4500 < larger < 5500
end

const vols = parameter(
	name = "Volumes",
	id = :volumes,
	size = 1000,
	children = [
		parameter(
			name = "Volume",
			id = :volume,
			value = 20.0,
			units = "L",
			transformer = x -> x / 1000.0,
			perturbation = 0.1)],
	transformer = (; args...) -> Dict{Symbol, Any}(args))

@test value(vols) == Dict(:broadcastsize => 1000, :volume => 20.0)

@test typeof(transform(vols)) == Vector{Dict{Symbol, Any}}

let v = transform(vols), err = 0.0, larger = 0, n = broadcastsize(vols)
	for i=1:n
		if v[i][:volume] > 0.02
			larger += 1
		end
		err += abs(v[i][:volume] - 0.02)
	end
	err /= 0.02   # relative error
	err /= n      # average relative error
	@test 0.045 < err < 0.055
	@test (n/2 * 0.95) < larger < (n/2 * 1.05)
end

end # module
