import Test: @testset, @test, @test_throws
import UnsafePointers: UnsafePtr

@testset "UnsafePtr" begin
    @testset "scalar get/set" begin
        x = Ref(1)
        uptr = UnsafePtr(x)
        uptr[] = 2
        @test x[] == 2
        @test uptr[] == x[]
        @test_throws InexactError uptr[] = 1.2
        @test pointer(uptr) == Base.unsafe_convert(Ptr{Int}, x)
    end

    @testset "array get/set" begin
        xs = Int[1, 2, 3]
        uptr = UnsafePtr(xs)
        @test uptr[1] == 1
        uptr[3] = 42
        @test xs[end] == 42
        @test_throws InexactError uptr[1] = 1.2
        @test uptr[[1, 3]] == [1, 42]
        @test uptr[!, [2, 3]] == [2, 42]
    end

    @testset "string conversion" begin
        chars = UInt8.(collect("foo\0"))
        @test String(UnsafePtr(chars)) == "foo"
    end

    @testset "doautowrap" begin
        chars = UInt8.(collect("foo\0"))
        c_str = Cstring(pointer(chars))
        @test UnsafePtr{Cstring}(c_str)[] isa UnsafePtr
    end

    @testset "field access" begin
        struct FieldFixture
            a::Int
            b::Tuple{Float64, Int}
            c::Ptr{Int}
        end

        ints = collect(10:10:60)
        fixture = Ref(FieldFixture(5, (1.5, 42), pointer(ints)))
        p = UnsafePtr(fixture)

        @test p.a[] == 5
        @test p.b[] == (1.5, 42)
        @test p.b._2[] == 42

        second_field = getproperty(p, 2)
        @test second_field[] == (1.5, 42)
        @test second_field == p.b

        cfield = p.c
        @test cfield[] isa UnsafePtr{Int}
        @test cfield[!] == pointer(ints)

        firstptr = cfield[]
        @test firstptr[] == ints[1]
        firstptr[3] = -30
        @test ints[3] == -30
    end

    @testset "pointer arithmetic" begin
        buf = collect(1:8)
        p = UnsafePtr(buf)

        q = p + 2
        @test q[] == buf[3]
        @test q - p == 2
        @test (p + 5) - q == 3
        mid = p + 3
        @test (mid - 2)[] == buf[2]

        q[] = 77
        @test buf[3] == 77

        ptr_ref = Ref(pointer(buf))
        wrapped_ptr = UnsafePtr(ptr_ref) # UnsafePtr{Ptr{Int}}
        auto = wrapped_ptr[]
        @test auto[] == buf[1]
        @test (auto + 4)[] == buf[5]
        @test (auto + 4) - auto == 4
        @test (4 + auto)[] == buf[5]

        raw = wrapped_ptr[!]
        @test raw == pointer(buf)
        @test unsafe_load(raw, 2) == buf[2]
    end

    @testset "array and view conversions" begin
        buf = collect(11:16)
        p = UnsafePtr(buf)

        @test Array(p, length(buf)) == buf
        @test Array{Int}(p, (length(buf),)) == buf
        @test Array{Int}(p, 2, 3) == reshape(buf, 2, 3)

        slice = view(p, 2:4)
        @test collect(slice) == buf[2:4]

        fancy = view(p, [1, 3, 5])
        @test collect(fancy) == buf[[1, 3, 5]]

        ptr_ref = Ref(pointer(buf))
        wrapped_ptr = UnsafePtr(ptr_ref)
        auto = wrapped_ptr[]
        @test Array(auto, length(buf)) == buf
        @test collect(view(auto, 3:6)) == buf[3:6]
        @test view(auto, 4)[] == buf[4]

        raw = wrapped_ptr[!]
        @test Array(UnsafePtr(raw), length(buf)) == buf
        any_vec = Array{T,1} where T
        @test any_vec(auto, length(buf)) == buf
    end

    @testset "string conversions" begin
        bytes = collect(codeunits("hello world"))
        p = UnsafePtr(bytes)
        @test String(p, length(bytes)) == "hello world"

        sub = p + 6
        @test String(sub, length(bytes) - 6) == "world"

        ptr_ref = Ref(pointer(bytes))
        wrapped_ptr = UnsafePtr(ptr_ref)
        auto = wrapped_ptr[]
        @test String(auto, length(bytes)) == "hello world"

        raw = wrapped_ptr[!]
        @test String(UnsafePtr(raw), length(bytes)) == "hello world"
    end

    @testset "conversions" begin
        buf = collect(21:26)
        p = UnsafePtr(buf)
        raw = pointer(buf)

        @test convert(Ptr{Int}, p) == raw
        @test Ptr{Int}(p) == raw

        narrowed = convert(UnsafePtr{Int}, raw)
        @test pointer(narrowed) == raw
        @test convert(UnsafePtr, raw) == UnsafePtr(raw)
        @test convert(UnsafePtr, p) === p
        @test convert(UnsafePtr{Int}, p) === p

        ref = Ref(Int32(7))
        typed_from_ref = UnsafePtr{Int32}(ref)
        @test typed_from_ref[] == 7
        typed_from_ptr = UnsafePtr{Int}(raw)
        @test pointer(typed_from_ptr) == raw
        reinterpreted = UnsafePtr{UInt8}(p)
        @test pointer(reinterpreted) == pointer(p)
        @test UnsafePtr(p) === p

        if !isdefined(@__MODULE__, :FakePointer)
            struct FakePointer
                ptr::Ptr{Int}
            end
        end
        Base.convert(::Type{Ptr}, fake::FakePointer) = fake.ptr
        Base.convert(::Type{Ptr{Int}}, fake::FakePointer) = fake.ptr
        fake = FakePointer(raw)
        @test convert(UnsafePtr, fake) == UnsafePtr(raw)
        @test pointer(convert(UnsafePtr{Int}, fake)) == raw

        @test Base.unsafe_convert(Ptr{Int}, p) == raw
        @test Base.unsafe_convert(Ptr{Int}, narrowed) == raw
        @test Base.unsafe_convert(Ptr, p) == raw

        holder_ref = Ref(pointer(buf))
        holder = UnsafePtr(holder_ref)
        shifted = raw + sizeof(Int)
        holder[!, 1] = shifted
        @test holder[!, 1] == shifted
    end

    @testset "metadata and errors" begin
        struct MetaFixture
            a::Int
            b::Float64
        end

        fixture = Ref(MetaFixture(1, 2.0))
        p = UnsafePtr(fixture)

        shown = sprint(show, p)
        @test occursin("UnsafePtr", shown)
        @test occursin("@", shown)

        @test propertynames(p) == fieldnames(MetaFixture)
        @test_throws ErrorException p.c
        @test_throws ErrorException p.a = 2
        @test_throws ErrorException getproperty(p, 3)
        @test_throws ErrorException setproperty!(p, 1, nothing)

        other = UnsafePtr{MetaFixture}(p)
        @test other == p
        rawptr = Base.unsafe_convert(Ptr{MetaFixture}, fixture)
        @test other == rawptr
        @test rawptr == other
    end

    @testset "boolean indexing" begin
        refs = [Ref(i) for i in 1:5]
        ptrs = Ptr{Int}[Base.unsafe_convert(Ptr{Int}, r) for r in refs]
        parr = UnsafePtr(ptrs)
        mask = [true, false, true, false, true]

        wrapped = parr[mask]
        @test all(w isa UnsafePtr{Int} for w in wrapped)
        @test [w[] for w in wrapped] == [r[] for (r, m) in zip(refs, mask) if m]

        raw = parr[!, mask]
        @test raw == ptrs[mask]
    end

    @testset "views and iteration" begin
        data = collect(41:50)
        p = UnsafePtr(data)

        empty_view = view(p, Int[])
        @test size(empty_view) == (0,)
        @test collect(empty_view) == Int[]

        taken = collect(Base.Iterators.take(p, 4))
        @test taken == data[1:4]
    end
end
