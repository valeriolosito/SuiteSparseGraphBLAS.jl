function get_GrB_Type(T::DataType)
    if T == Bool
        return GrB_BOOL
    elseif T == Int8
        return GrB_INT8
    elseif T == UInt8
        return GrB_UINT8
    elseif T == Int16
        return GrB_INT16
    elseif T == UInt16
        return GrB_UINT16
    elseif T == Int32
        return GrB_INT32
    elseif T == UInt32
        return GrB_UINT32
    elseif T == Int64
        return GrB_INT64
    elseif T == UInt64
        return GrB_UINT64
    elseif  T == Float32
        return GrB_FP32
    end
    return GrB_FP64
end

function default_dup(T::DataType)
    if T == Bool
        return GrB_FIRST_BOOL
    elseif T == Int8
        return GrB_FIRST_INT8
    elseif T == UInt8
        return GrB_FIRST_UINT8
    elseif T == Int16
        return GrB_FIRST_INT16
    elseif T == UInt16
        return GrB_FIRST_UINT16
    elseif T == Int32
        return GrB_FIRST_INT32
    elseif T == UInt32
        return GrB_FIRST_UINT32
    elseif T == Int64
        return GrB_FIRST_INT64
    elseif T == UInt64
        return GrB_FIRST_UINT64
    elseif  T == Float32
        return GrB_FIRST_FP32
    end
    return GrB_FIRST_FP64
end

function equal_op(T::DataType)
    if T == Bool
        return GrB_EQ_BOOL
    elseif T == Int8
        return GrB_EQ_INT8
    elseif T == UInt8
        return GrB_EQ_UINT8
    elseif T == Int16
        return GrB_EQ_INT16
    elseif T == UInt16
        return GrB_EQ_UINT16
    elseif T == Int32
        return GrB_EQ_INT32
    elseif T == UInt32
        return GrB_EQ_UINT32
    elseif T == Int64
        return GrB_EQ_INT64
    elseif T == UInt64
        return GrB_EQ_UINT64
    elseif  T == Float32
        return GrB_EQ_FP32
    end
    return GrB_EQ_FP64
end

function type_suffix(T::DataType)
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

function GrB_op(fun_name, T)
    return eval(Symbol("GrB_", uppercase(fun_name), "_", type_suffix(T)))
end

function GxB_op(fun_name, T)
    return eval(Symbol("GxB_", uppercase(fun_name), "_", type_suffix(T)))
end

function check(status)
    if status != GrB_SUCCESS
        error(status)
    end
end