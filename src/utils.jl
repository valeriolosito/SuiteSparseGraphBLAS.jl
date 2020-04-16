struct GraphBlasException <: Exception
    error::String
end

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

@enum GrB_Info begin
    GrB_SUCCESS = 0                 # all is well
    GrB_NO_VALUE = 1                # A(ij) requested but not there
    GrB_UNINITIALIZED_OBJECT = 2    # object has not been initialized
    GrB_INVALID_OBJECT = 3          # object is corrupted
    GrB_NULL_POINTER = 4            # input pointer is NULL
    GrB_INVALID_VALUE = 5           # generic error code; some value is bad
    GrB_INVALID_INDEX = 6           # a row or column index is out of bounds
    GrB_DOMAIN_MISMATCH = 7         # object domains are not compatible
    GrB_DIMENSION_MISMATCH = 8      # matrix dimensions do not match
    GrB_OUTPUT_NOT_EMPTY = 9        # output matrix already has values in it
    GrB_OUT_OF_MEMORY = 10          # out of memory
    GrB_INSUFFICIENT_SPACE = 11     # output array not large enough
    GrB_INDEX_OUT_OF_BOUNDS = 12    # a row or column index is out of bounds
    GrB_PANIC = 13                  # SuiteSparse:GraphBLAS only panics if a critical section fails
end

function check(info)
    if info != GrB_SUCCESS
        throw(GraphBlasException(string(info)))
    end
end

function suffix(T::DataType)
    if T == Bool
        return "BOOL"
    elseif T == Int8
        return "INT8"
    elseif T == UInt8
        return "UINT8"
    elseif T == Int16
        return "INT16"
    elseif T == UInt16
        return "UINT16"
    elseif T == Int32
        return "INT32"
    elseif T == UInt32
        return "UINT32"
    elseif T == Int64
        return "INT64"
    elseif T == UInt64
        return "UINT64"
    elseif  T == Float32
        return "FP32"
    end
    return "FP64"
end

function load_global(str)
    x = dlsym(graphblas_lib, str)
    return unsafe_load(cglobal(x, Ptr{Cvoid}))
end

function load_buildin_op(dict, lst, T)
    for op in lst
        k = Symbol(join(split(op, "_")[2:end-1]))
        unaryops = get!(dict, k, [])
        push!(unaryops, T(op))
    end
end
