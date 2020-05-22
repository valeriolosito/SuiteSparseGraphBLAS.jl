import Base: size, copy, lastindex, setindex!, getindex, show, ==, *, Broadcast.broadcasted, |>, reduce

_gb_pointer(m::GBVector) = m.p

"""
    vector_from_type(type, n)

Create an empty GBVector of size `n` from the given type `type`.

"""
function vector_from_type(type, n)
    v = GBVector{type.jtype}()
    GrB_Vector_new(v, type, n)
    finalizer(_free, v)
    return v
end

"""
    vector_from_lists(I, V; n = nothing, type = NULL, combine = NULL)

Create a new GBVector from the given lists of indices and values.
If `n` is not provided, it is computed from the max value of the indices list.
If `type` is not provided, it is inferred from the values list.
A combiner Binary Operator can be provided to manage duplicates values. If it is not provided, the default `BinaryOp.FIRST` is used.

# Arguments
- `I`: the list of indices.
- `V`: the list of values.
- `n`: the size of the vector.
- `type`: the GBType of the GBVector.
- `combine`: the `BinaryOperator` which assembles any duplicate entries with identical indices.

"""
function vector_from_lists(I, V; n = nothing, type = NULL, combine = NULL)
    @assert length(I) == length(V) 
    if n == nothing
        n = maximum(I)
    end
    if type == NULL
        type = j2gtype(eltype(V))
    elseif type.jtype != eltype(V)
        V = convert.(type.jtype, V)
    end

    if combine == NULL
        combine = Binaryop.FIRST
    end
    combine_bop = _get(combine, type, type, type)
    I = map(x->x - 1, I)
    v = vector_from_type(type, n)
    GrB_Vector_build(v, I, V, length(V), combine_bop)
    return v
end

"""
    from_vector(V)

Create a GBVector from the given Vector `m`.

"""
function from_vector(V)
    size = length(V)
    @assert size > 0
    res = vector_from_type(j2gtype(eltype(V)), size)
    
    for (i, v) in enumerate(V)
        if !iszero(V[i])
            res[i] = V[i]
        end
    end
    return res
end

function show(io::IO, ::MIME"text/plain", v::GBVector{T}) where T
    print(io, "$(Int64(size(v)))-element GBVector{$(T)} ")
    println(io, "with $(nnz(v)) stored entries:")

    for (i, x) in zip(findnz(v)...)
        println("  [$i] = $x")
    end
end

"""
    ==(u, v) -> Bool

Check if two vectors `u` and `v` are equal.
"""
function ==(u::GBVector{T}, v::GBVector{U}) where {T, U}
    T != U && return false

    usize = size(u)
    unvals = nnz(u)

    usize == size(v) || return false
    unvals == nnz(v) || return false

    @with Binaryop.EQ, Monoids.LAND begin
        w = emult(u, v, out=vector_from_type(BOOL, usize))
        eq = reduce(w)
    end
    
    return eq
end

*(u::GBVector, A::GBMatrix) = vxm(u, A)

broadcasted(::typeof(+), u::GBVector, v::GBVector) = eadd(u, v)
broadcasted(::typeof(*), u::GBVector, v::GBVector) = emult(u, v)

|>(A::GBVector, op::UnaryOperator) = apply(A, unaryop = op)

"""
    size(v::GBVector)

Return the dimension of v.
Optionally you can specify a dimension to just get the length of that dimension.

# Examples
```julia-repl
julia> v = from_vector([1, 2, 3]);

julia> size(v)
3
```
"""
function size(v::GBVector)
    return Int64(GrB_Vector_size(v))
end

"""
    nnz(v::GBVector)

Return the number of entries in a vector `v`.

# Examples
```julia-repl
julia> v = from_vector([1, 2, 0]);

julia> nnz(v)
2
```
"""
function nnz(v::GBVector)
    return Int64(GrB_Vector_nvals(v))
end

"""
    findnz(v::GBVector)

Return a tuple `(I, V)` where `I` is the indices lists of the "non-zero" values in `m`, and `V` is a list of "non-zero" values.

# Examples
```julia-repl
julia> v = from_vector([1, 2, 0, 0, 0, 1]);

julia> findnz(v)
([1, 2, 6], [1, 2, 1])
```
"""
function findnz(v::GBVector)
    I, V = GrB_Vector_extractTuples(v)
    map!(x -> x+1, I, I)
    return I, V
end

"""
    copy(v::GBVector)

Create a copy of `v`.

"""
function copy(v::GBVector)
    cpy = vector_from_type(v.type, size(v))
    GrB_Vector_dup(cpy, v)
    return cpy
end

"""
    clear!(v::GBVector)

Clear all entries from a vector `v`.

"""
function clear!(v::GBVector)
    GrB_Vector_clear(v)
end

"""
    lastindex(v::GBMatrix)

Return the last index of a vector `v`.

# Examples
```julia-repl
julia> v = from_vector([1, 2, 0, 0, 0, 1]);

julia> lastindex(v)
6
```
"""
function lastindex(v::GBVector)
    return size(v)
end

function setindex!(v::GBVector{T}, value, i::Integer) where T
    value = convert(T, value)
    GrB_Vector_setElement(v, value, i - 1)
end

setindex!(v::GBVector, value, i::Union{UnitRange,Vector}) = _assign!(v, value, _zero_based_indexes(i))
setindex!(v::GBVector, value, ::Colon) = _assign!(v, value, GrB_ALL)

function getindex(v::GBVector, i::Integer)
    try
        return GrB_Vector_extractElement(v, i - 1)
    catch e
        if e isa GraphBLASNoValueException
            return v.type.zero
        else
            rethrow(e)
        end
    end
end

getindex(v::GBVector, i::Union{UnitRange,Vector}) = _extract(v, _zero_based_indexes(i))
getindex(v::GBVector, ::Colon) = copy(v)

"""
    emult(u::GBVector, v::GBVector; kwargs...)

Compute the element-wise "multiplication" of two vector `u` and `v`, using a `Binary Operator`, a `Monoid` or a `Semiring`.
If given a `Monoid`, the additive operator of the monoid is used as the multiply binary operator.
If given a `Semiring`, the multiply operator of the semiring is used as the multiply binary operator.

# Arguments
- `u`: the first vector.
- `v`: the second vector.
- `[out]`: the output vector for result.
- `[operator]`: the operator to use. Can be either a Binary Operator, a Monoid or a Semiring.
- `[accum]`: optional accumulator.
- `[mask]`: optional mask.
- `[desc]`: descriptor for `out`, `mask`, `u` and `v`.

# Examples
```julia-repl
julia> u = from_vector([1, 2, 3, 4]);

julia> v = copy(u);

julia> emult(u, v, operator = Binaryop.PLUS)
4-element GBVector{Int64} with 4 stored entries:
  [1] = 2
  [2] = 4
  [3] = 6
  [4] = 8

```
"""
function emult(u::GBVector, v::GBVector; kwargs...)
    out, operator, mask, accum, desc = __get_args(kwargs)
    
    # operator: can be binary op, monoid and semiring
    if out === NULL
        out = vector_from_type(u.type, size(u))
    end

    if operator === NULL
        operator = g_operators.binaryop
    end
    operator_impl = _get(operator, out.type, u.type, v.type)

    suffix = split(string(typeof(operator_impl)), "_")[end]

    check(
        ccall(
            dlsym(graphblas_lib, "GrB_eWiseMult_Vector_" * suffix),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            _gb_pointer(out), _gb_pointer(mask), _gb_pointer(accum), _gb_pointer(operator_impl),
            _gb_pointer(u), _gb_pointer(v), _gb_pointer(desc)
            )
        )

    return out
end

"""
    eadd(u::GBVector, v::GBVector; kwargs...)

Compute the element-wise "addition" of two vectors `u` and `v`, using a `Binary Operator`, a `Monoid` or a `Semiring`.
If given a `Monoid`, the additive operator of the monoid is used as the add binary operator.
If given a `Semiring`, the additive operator of the semiring is used as the add binary operator.
    
# Arguments
- `u`: the first vector.
- `v`: the second vector.
- `[out]`: the output vector for result.
- `[operator]`: the operator to use. Can be either a Binary Operator, a Monoid or a Semiring.
- `[accum]`: optional accumulator.
- `[mask]`: optional mask.
- `[desc]`: descriptor for `out`, `mask`, `u` and `v`.

# Examples
```julia-repl
julia> u = from_vector([1, 2, 3, 4]);

julia> v = copy(u);

julia> emult(u, v, operator = Binaryop.TIMES)
4-element GBVector{Int64} with 4 stored entries:
  [1] = 1
  [2] = 4
  [3] = 9
  [4] = 16

```
"""
function eadd(u::GBVector, v::GBVector; kwargs...)
    out, operator, mask, accum, desc = __get_args(kwargs)

    # operator: can be binary op, monoid and semiring
    if out === NULL
        out = vector_from_type(u.type, size(u))
    end

    if operator === NULL
        operator = g_operators.binaryop
    end
    operator_impl = _get(operator, out.type, u.type, v.type)

    suffix = split(string(typeof(operator_impl)), "_")[end]

    check(
        ccall(
            dlsym(graphblas_lib, "GrB_eWiseAdd_Vector_" * suffix),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            _gb_pointer(out), _gb_pointer(mask), _gb_pointer(accum), _gb_pointer(operator_impl),
            _gb_pointer(u), _gb_pointer(v), _gb_pointer(desc)
            )
        )

    return out
end

"""
    vxm(u::GBVector, A::GBMatrix; kwargs...) -> GBVector

Multiply a row vector `u` times a matrix `A`.

# Arguments
- `u`: the row vector.
- `A`: the sparse matrix.
- `[out]`: the output vector for result.
- `[semiring]`: the semiring to use.
- `[accum]`: optional accumulator.
- `[mask]`: optional mask.
- `[desc]`: descriptor for `out`, `mask` and `A`.

# Examples
```julia-repl
julia> u = from_vector([1, 2]);

julia> A = from_matrix([1 2; 3 4]);

julia> vxm(u, A, semiring = Semirings.PLUS_TIMES)
2-element GBVector{Int64} with 2 stored entries:
  [1] = 7
  [2] = 10

```
"""
function vxm(u::GBVector, A::GBMatrix; kwargs...)
    rowA, colA = size(A)
    @assert size(u) == rowA

    out, semiring, mask, accum, desc = __get_args(kwargs)

    if out === NULL
        out = vector_from_type(u.type, colA)
    end

    if semiring === NULL
        semiring = g_operators.semiring
    end
    semiring_impl = _get(semiring, out.type, u.type, A.type)
    
    check(
        ccall(
            dlsym(graphblas_lib, "GrB_vxm"),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            _gb_pointer(out), _gb_pointer(mask), _gb_pointer(accum), _gb_pointer(semiring_impl),
            _gb_pointer(u), _gb_pointer(A), _gb_pointer(desc)
            )
        )
    
    return out
end

"""
    apply(u::GBVector; kwargs...) -> GBVector

Apply a `Unary Operator` to the entries of a vector `u`, creating a new vector.

# Arguments
- `u`: the sparse vector.
- `[out]`: the output vector for result.
- `[unaryop]`: the unary operator to use.
- `[accum]`: optional accumulator.
- `[mask]`: optional mask.
- `[desc]`: descriptor for `out` and `mask`.

# Examples
```julia-repl
julia> u = from_vector([-1, 2, -3]);

julia> apply(u, unaryop = Unaryop.ABS)
3-element GBVector{Int64} with 3 stored entries:
  [1] = 1
  [2] = 2
  [3] = 3

```
"""
function apply(u::GBVector; kwargs...)
    out, unaryop, mask, accum, desc = __get_args(kwargs)
    
    if out === NULL
        out = vector_from_type(u.type, size(u))
    end

    if unaryop === NULL
        unaryop = g_operators.unaryop
    end
    unaryop_impl = _get(unaryop, out.type, u.type)

    check(
        ccall(
            dlsym(graphblas_lib, "GrB_Vector_apply"),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            _gb_pointer(out), _gb_pointer(mask), _gb_pointer(accum), _gb_pointer(unaryop_impl),
            _gb_pointer(u), _gb_pointer(desc)
            )
        )

    return out
end

"""
    apply!(A::GBMatrix; kwargs...)

Apply a `Unary Operator` to the entries of a vector `u`.

# Arguments
- `u`: the sparse vector.
- `[unaryop]`: the unary operator to use.
- `[accum]`: optional accumulator.
- `[mask]`: optional mask.
- `[desc]`: descriptor for `out` and `mask`.

# Examples
```julia-repl
julia> u = from_vector([-1, 2, -3]);

julia> apply!(u, unaryop = Unaryop.ABS);

julia> u
3-element GBVector{Int64} with 3 stored entries:
  [1] = 1
  [2] = 2
  [3] = 3

```
"""
function apply!(u::GBVector; kwargs...)
    _, unaryop, mask, accum, desc = __get_args(kwargs)
    return apply(u, out = u, unaryop = unaryop, mask = mask, accum = accum, desc = desc)
end

# TODO: select

"""
    reduce(u::GBVector{T}; kwargs...) -> T

Reduce a vector `u` to a scalar, using the given `Monoid`.

# Arguments
- `u`: the sparse vector to reduce.
- `[monoid]`: monoid to do the reduction.
- `[accum]`: optional accumulator.

# Examples
```julia-repl
julia> u = from_vector([1, 2, 3, 4]);

julia> reduce(u, monoid = Monoids.PLUS)
10
```
"""
function reduce(u::GBVector{T}; kwargs...) where T
    _, monoid, _, accum, desc = __get_args(kwargs)
    
    if monoid === NULL
        monoid = g_operators.monoid
    end
    monoid_impl = _get(monoid, u.type)

    scalar = Ref(T(0))

    check(
        ccall(
            dlsym(graphblas_lib, "GrB_Vector_reduce_" * suffix(T)),
            Cint,
            (Ptr{T}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            scalar, _gb_pointer(accum), _gb_pointer(monoid_impl), _gb_pointer(u), _gb_pointer(desc)
            )
        )

    return scalar[]
end

function _extract(u::GBVector, indices::Vector{I}; kwargs...) where I <: Union{UInt64,Int64}
    ni = length(indices)
    @assert ni > 0

    out, _, mask, accum, desc = __get_args(kwargs)

    if out === NULL
        out = vector_from_type(u.type, ni)
    end

    check(
        ccall(
            dlsym(graphblas_lib, "GrB_Vector_extract"),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{I}, Cuintmax_t, Ptr{Cvoid}),
            _gb_pointer(out), _gb_pointer(mask), _gb_pointer(accum), _gb_pointer(u),
            pointer(indices), ni, _gb_pointer(desc)
            )
        )

    return out
end

function _assign!(u::GBVector, v::GBVector, indices::Union{Vector{I},GSpecial}; kwargs...) where I <: Union{UInt64,Int64}
    _, _, mask, accum, desc = __get_args(kwargs)
    
    check(
        ccall(
            dlsym(graphblas_lib, "GrB_Vector_assign"),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cuintmax_t, Ptr{Cvoid}),
            _gb_pointer(u), _gb_pointer(mask), _gb_pointer(accum),
            _gb_pointer(v), pointer(indices), length(indices), _gb_pointer(desc)
            )
        )
        
end

function _free(v::GBVector)
    check(
        ccall(
            dlsym(graphblas_lib, "GrB_Vector_free"),
            Cint,
            (Ptr{Cvoid},),
            pointer_from_objref(v)
            )
        )
end
