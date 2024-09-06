import Test: @testset, @test, @test_throws
import UnsafePointers: UnsafePtr

@testset "UnsafePtr" begin
    # Test scalar get/set
    x = Ref(1)
    uptr = UnsafePtr(x)
    uptr[] = 2
    @test x[] == 2
    @test uptr[] == x[]
    @test_throws InexactError uptr[] = 1.2
    @test pointer(uptr) == Base.unsafe_convert(Ptr{Int}, x)

    # Test array get/set
    xs = Int[1, 2, 3]
    uptr = UnsafePtr(xs)
    @test uptr[1] == 1
    uptr[3] = 42
    @test xs[end] == 42
    @test_throws InexactError uptr[1] = 1.2

    # Test string conversion
    chars = UInt8.(collect("foo\0"))
    @test String(UnsafePtr(chars)) == "foo"

    # Test doautowrap()
    c_str = Cstring(pointer(chars))
    @test UnsafePtr{Cstring}(c_str)[] isa UnsafePtr
end
