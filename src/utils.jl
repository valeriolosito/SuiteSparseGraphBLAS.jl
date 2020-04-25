struct GraphBLASNoValueException <: Exception end
struct GraphBLASUninitializedObjectException <: Exception end
struct GraphBLASInvalidObjectException <: Exception end
struct GraphBLASNullPointerException <: Exception end
struct GraphBLASInvalidValueException <: Exception end
struct GraphBLASInvalidIndexException <: Exception end
struct GraphBLASDomainMismatchException <: Exception end
struct GraphBLASDimensionMismatchException <: Exception end
struct GraphBLASOutputNotEmptyException <: Exception end
struct GraphBLASOutOfMemoryException <: Exception end
struct GraphBLASInsufficientSpaceException <: Exception end
struct GraphBLASIndexOutOfBoundException <: Exception end
struct GraphBLASPanicException <: Exception end

function compile(lst...)
    res = String[]
    if length(lst) == 1
        return lst[1]
    else
        r = compile(lst[2:end]...)
        for e in r
            for l in lst[1]
                push!(res, "$(l)_$(e)")
            end
        end
        return res
    end
end

function check(info)
    if info == 1        # NO_VALUE
        throw(GraphBLASNoValueException())
    elseif info == 2    # UNINITIALIZED_OBJECT
        throw(GraphBLASUninitializedObjectException())
    elseif info == 3    # INVALID_OBJECT
        throw(GraphBLASInvalidObjectException())
    elseif info == 4    # NULL_POINTER
        throw(GraphBLASNullPointerException())
    elseif info == 5    # GrB_INVALID_VALUE
        throw(GraphBLASInvalidValueException())
    elseif info == 6    # GrB_INVALID_INDEX
        throw(GraphBLASInvalidIndexException())
    elseif info == 7    # DOMAIN_MISMATCH
        throw(GraphBLASDomainMismatchException())
    elseif info == 8    # DIMENSION_MISMATCH
        throw(GraphBLASDimensionMismatchException())
    elseif info == 9    # OUTPUT_NOT_EMPTY
        throw(GraphBLASOutputNotEmptyException())
    elseif info == 10   # OUT_OF_MEMORY
        throw(GraphBLASOutOfMemoryException())
    elseif info == 11   # INSUFFICIENT_SPACE
        throw(GraphBLASInsufficientSpaceException())
    elseif info == 12   # INDEX_OUT_OF_BOUNDS
        throw(GraphBLASIndexOutOfBoundException())
    elseif info == 13   # PANIC
        throw(GraphBLASPanicException())
    end
end

function load_global(str)
    x = dlsym(graphblas_lib, str)
    return unsafe_load(cglobal(x, Ptr{Cvoid}))
end

function gbtype_from_jtype(T::DataType)
    return load_global("GrB_" * suffix(T))
end

function with(block, args...)
    global g_operators

    # change and store default operators
    old_op = []
    for op in args
        push!(old_op, __enter__(op))
    end

    println(g_operators)
    # execute code block
    block()

    # restore default operators
    g_operators = merge(g_operators, old_op...)

end 