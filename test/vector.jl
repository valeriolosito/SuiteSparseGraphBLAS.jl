@testset "Vector" begin

    # from_type method
    for t in valid_types
        type = SG._gb_type(t)
        vector_type = SG.from_type(t, 10)
        @test vector_type.type == type
        @test SG.size(vector_type) == 10
        I, X = SG.findnz(vector_type)
        @test isempty(I) && isempty(X)
    end

    # from_lists method

    # automatic type inference and size from values from lists
    I, X = [1,2,4,5], Int64[1,2,3,4]
    v = SG.from_lists(I, X)
    @test v.type == SG.INT64
    @test size(v) == 5

    # automatic type inference, given size
    I, X = [1,2,4,5], Int64[1,2,3,4]
    v = SG.from_lists(I, X, n = 10)
    @test v.type == SG.INT64
    @test size(v) == 10

    # passed type parameter
    I, X = [1,2,4,5], Int8[1,2,3,4]
    v = SG.from_lists(I, X, n = 10, type = Int32)
    @test v.type == SG.INT32
    @test size(v) == 10

    # combine parameter - default (FIRST)
    I, X = [1,1,4,5], Int8[1,2,3,4]
    v = SG.from_lists(I, X, n = 10)
    @test v.type == SG.INT8
    @test size(v) == 10
    @test v[1] == 1
    @test SG.nnz(v) == 3

    # combine parameter - given
    I, X = [1,1,4,5], Int8[1,2,3,4]
    v = SG.from_lists(I, X, combine = Binaryop.PLUS)
    @test v.type == SG.INT8
    @test size(v) == 5
    @test v[1] == 3
    @test SG.nnz(v) == 3

    # findnz
    I, X = [1,2,4,5], Int8[1,2,3,4]
    v = SG.from_lists(I, X)
    @test SG.findnz(v) == (I, X)

    # clear
    I, X = [1,2,4,5], Int8[1,2,3,4]
    v = SG.from_lists(I, X)
    @test SG.findnz(v) == (I, X)
    SG.clear!(v)
    I, X = SG.findnz(v)
    @test isempty(I) && isempty(X)

    # getindex
    I, X = [1,2,3,4], Int8[1,2,3,4]
    v = SG.from_lists(I, X)
    @test v[1] == 1
    @test v[2] == 2
    @test v[3] == 3
    @test v[4] == 4
    @test v[end] == 4
    @test typeof(v[1]) == Int8

    # setindex!
    I, X = [1,2,3,4], Int8[1,2,3,4]
    v = SG.from_lists(I, X)
    v[1] = 10
    v[2] = 20
    @test v[1] == 10
    @test v[2] == 20
    @test v[3] == 3
    @test v[4] == 4
    @test v[end] == 4

    # from_vector
    v = SG.from_vector(Int32[1,2,3])
    @test v.type == SG.INT32
    @test v[1] == 1 && v[2] == 2 && v[3] == 3

    
    # emult

    # binary op
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector(Int64[6,7,8,9,10])
    out = SG.emult(u, v, operator = Binaryop.PLUS)
    @test size(out) == 5
    @test out.type == SG.INT64
    @test out[1] == 7
    @test out[2] == 9
    @test out[3] == 11
    @test out[4] == 13
    @test out[5] == 15

    # monoid
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector(Int64[6,7,8,9,10])
    out = SG.emult(u, v, operator = Monoids.PLUS)
    @test size(out) == 5
    @test out.type == SG.INT64
    @test out[1] == 7
    @test out[2] == 9
    @test out[3] == 11
    @test out[4] == 13
    @test out[5] == 15

    # semiring
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector(Int64[6,7,8,9,10])
    out = SG.emult(u, v, operator = Semirings.TIMES_PLUS)
    @test size(out) == 5
    @test out.type == SG.INT64
    @test out[1] == 7
    @test out[2] == 9
    @test out[3] == 11
    @test out[4] == 13
    @test out[5] == 15


    # eadd

    # binary op
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector(Int64[6,7,8,9,10])
    out = SG.eadd(u, v, operator = Binaryop.TIMES)
    @test size(out) == 5
    @test out.type == SG.INT64
    @test out[1] == 6
    @test out[2] == 14
    @test out[3] == 24
    @test out[4] == 36
    @test out[5] == 50

    # monoid
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector(Int64[6,7,8,9,10])
    out = SG.eadd(u, v, operator = Monoids.TIMES)
    @test size(out) == 5
    @test out.type == SG.INT64
    @test out[1] == 6
    @test out[2] == 14
    @test out[3] == 24
    @test out[4] == 36
    @test out[5] == 50

    # semiring
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector(Int64[6,7,8,9,10])
    out = SG.eadd(u, v, operator = Semirings.TIMES_PLUS)
    @test size(out) == 5
    @test out.type == SG.INT64
    @test out[1] == 6
    @test out[2] == 14
    @test out[3] == 24
    @test out[4] == 36
    @test out[5] == 50


    # vxm
    v = SG.from_vector(Int64[1,2])
    A = SG.from_lists([1,1,2,2], [1,2,1,2], [1,2,3,4])
    out = SG.vxm(v, A, semiring = Semirings.PLUS_TIMES)
    @test size(out) == 2
    @test out[1] == 7
    @test out[2] == 10


    # apply

    v = SG.from_vector(Int64[-1,-2,3,-4])
    out = SG.apply(v, unaryop = Unaryop.ABS)
    @test out.type == SG.INT64
    @test size(v) == size(out)
    @test out[1] == 1
    @test out[2] == 2
    @test out[3] == 3
    @test out[4] == 4

    dup = SG.unaryop(a->a * 2)
    v = SG.from_vector(Int64[1,2,3,4])
    out = SG.apply(v, unaryop = dup)
    @test out.type == SG.INT64
    @test size(v) == size(out)
    @test out[1] == 2
    @test out[2] == 4
    @test out[3] == 6
    @test out[4] == 8

    v = SG.from_vector(Int8[1,2,3,4])
    out = SG.apply(v, unaryop = dup)
    @test out.type == SG.INT8
    @test size(v) == size(out)
    @test out[1] == 2
    @test out[2] == 4
    @test out[3] == 6
    @test out[4] == 8

    v = SG.from_vector(Float64[1,2,3,4])
    out = SG.apply(v, unaryop = dup)
    @test out.type == SG.FP64
    @test size(v) == size(out)
    @test out[1] == Float64(2)
    @test out[2] == Float64(4)
    @test out[3] == Float64(6)
    @test out[4] == Float64(8)



    # apply!
    
    v = SG.from_vector(Int64[-1,-2,3,-4])
    SG.apply!(v, unaryop = Unaryop.ABS)
    @test v[1] == 1
    @test v[2] == 2
    @test v[3] == 3
    @test v[4] == 4

    v = SG.from_vector(Int64[1,2,3,4])
    SG.apply!(v, unaryop = dup)
    @test v[1] == 2
    @test v[2] == 4
    @test v[3] == 6
    @test v[4] == 8

    v = SG.from_vector(Int8[1,2,3,4])
    SG.apply!(v, unaryop = dup)
    @test v[1] == 2
    @test v[2] == 4
    @test v[3] == 6
    @test v[4] == 8

    v = SG.from_vector(Float64[1,2,3,4])
    SG.apply!(v, unaryop = dup)
    @test v[1] == Float64(2)
    @test v[2] == Float64(4)
    @test v[3] == Float64(6)
    @test v[4] == Float64(8)


    # reduce
    u = SG.from_vector(Int64[1,2,3,4,5])
    out = SG.reduce(u, monoid = Monoids.PLUS)
    @test typeof(out) == Int64
    @test out == 15

    u = SG.from_vector(Int64[1,2,10,4,5])
    out = SG.reduce(u, monoid = Monoids.MAX)
    @test out == 10

    u = SG.from_vector([true, false, true])
    out = SG.reduce(u, monoid = Monoids.LAND)
    @test out == true
    out = SG.reduce(u, monoid = Monoids.LOR)
    @test out == true


    # extract sub vector
    u = SG.from_vector(Int64[1,2,3,4,5])
    out = SG._extract(u, [0,4])
    @test size(out) == 2
    @test isa(out, SG.GBVector)
    @test out[1] == 1
    @test out[2] == 5


    # getindex
    u = SG.from_vector(Int64[1,2,3,4,5])
    out = u[[1,5]]
    @test size(out) == 2
    @test isa(out, SG.GBVector)
    @test out[1] == 1
    @test out[2] == 5

    u = SG.from_vector(Int64[1,2,3,4,5])
    out = u[3:5]
    @test size(out) == 3
    @test isa(out, SG.GBVector)
    @test out[1] == 3
    @test out[2] == 4
    @test out[3] == 5


    # assign!
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector([10,11])
    SG._assign!(u, v, [2,3])
    @test u[1] == 1
    @test u[2] == 2
    @test u[3] == 10
    @test u[4] == 11
    @test u[5] == 5


    # setindex!
    # list indices
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector([10,20])
    u[[2,3]] = v
    @test size(u) == 5
    @test u[1] == 1 && u[2] == 10 && u[3] == 20 && u[4] == 4 && u[5] == 5

    # range
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector([10,20])
    u[2:3] = v
    @test size(u) == 5
    @test u[1] == 1 && u[2] == 10 && u[3] == 20 && u[4] == 4 && u[5] == 5

    # range with end
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector([10,20])
    u[4:end] = v
    @test size(u) == 5
    @test u[1] == 1 && u[2] == 2 && u[3] == 3 && u[4] == 10 && u[5] == 20

    # colon
    u = SG.from_vector(Int64[1,2,3,4,5])
    v = SG.from_vector([10,20,30,40,50])
    u[:] = v
    @test size(u) == 5
    @test u[1] == 10 && u[2] == 20 && u[3] == 30 && u[4] == 40 && u[5] == 50


end
