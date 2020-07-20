"""
    UnsafePointers

Provides the `UnsafePtr` type, providing convenient (but unsafe) pointer semantics.
"""
module UnsafePointers

    export UnsafePtr

    """
        UnsafePtr([T,] r)

    A pointer to the contents of `r` which may be a `Ptr`, `Ref`, or anything with a `pointer` method. `T` specifies the element type.

    It has convenient (but unsafe) semantics:
    * `p[]` dereferences the value, and can be assigned to.
    * `p[i]` dereferences the `i`th value, assuming the pointer points to an array.
    * `p.name` is an `UnsafePtr` to the `name` field of `p[]`.
    * `p+i` is an `UnsafePtr` to the `i`th next value. `(p+i-1)[]` and `p[i]` are equivalent.
    * Iteration yields `p[1]`, `p[2]`, ... forever.

    The first four operations have these C equivalents: `*p`, `p[i-1]`, `&(p->name)` and `p+i`.

    If the result of dereferencing would be a `Ptr`, an `UnsafePtr` is returned instead. Use `p[Ptr, i]` or `unsafe_load(p, i)` to avoid this.

    Use `pointer(p)` to retrieve the underlying `Ptr`.

    # Safety

    It is the caller's responsibility to ensure that the pointer remains valid, e.g. by ensuring that `r` is not garbage collected.

    You will likely crash Julia if you assign to a non-bitstype value.

    # Example

    Here we access and modify the individual fields of a (mutable) reference to a (immutable) named tuple.

    ```julia
    r = Ref((a=1, b=(c=2, d=3)))
    @show r[]       # (a = 1, b = (c = 2, d = 3))
    p = UnsafePtr(r)
    p.a[] = 99
    p.b.d[] *= 10
    @show r[]       # (a = 99, b = (c = 2, d = 30))
    ```
    """
    struct UnsafePtr{T} <: Ref{T}
        ptr :: Ptr{T}
        UnsafePtr{T}(p::Ptr) where {T} = new{T}(Ptr{T}(p))
    end

    function Base.show(io::IO, p::UnsafePtr)
        show(io, typeof(p))
        print(io, " @")
        show(io, convert(Integer, pointer(p)))
    end

    Base.pointer(p::UnsafePtr) = getfield(p, :ptr)

    # convert UnsafePtr -> Ptr
    Base.convert(P::Type{<:Ptr}, p::UnsafePtr) = convert(P, pointer(p))
    (P::Type{<:Ptr})(p::UnsafePtr) = P(pointer(p))

    # convert Ptr -> UnsafePtr
    Base.convert(P::Type{UnsafePtr}, p::Ptr) = UnsafePtr(p)
    Base.convert(P::Type{UnsafePtr{T}}, p::Ptr) where {T} = UnsafePtr(T, p)

    Base.unsafe_convert(P::Type{<:Union{Ptr,UnsafePtr}}, p::UnsafePtr) =
        Base.unsafe_convert(P, pointer(p))

    UnsafePtr(T::Type, p::UnsafePtr) = UnsafePtr{T}(pointer(p))
    UnsafePtr(T::Type, args...) = UnsafePtr(T, UnsafePtr(args...))

    UnsafePtr(p::Ptr{T}) where {T} = UnsafePtr{T}(p)
    UnsafePtr(p::UnsafePtr) = p
    UnsafePtr(r::Ref) = UnsafePtr(Base.unsafe_convert(Ptr{eltype(r)}, r))
    UnsafePtr(x) = UnsafePtr(pointer(x))

    Base.unsafe_load(p::UnsafePtr, i::Integer=1) =
        unsafe_load(pointer(p), i)

    Base.unsafe_store!(p::UnsafePtr, x, i::Integer=1) =
        unsafe_store!(pointer(p), x, i)

    Base.getindex(p::UnsafePtr, i::Integer=1) =
        unsafe_load(p, i)

    Base.getindex(p::UnsafePtr{<:Ptr}, i::Integer=1) =
        UnsafePtr(unsafe_load(p, i))

    Base.getindex(p::UnsafePtr, T::Type, i::Integer=1) =
        convert(T, unsafe_load(p, i))

    Base.setindex!(p::UnsafePtr, x, i::Integer=1) =
        unsafe_store!(p, x, i)

    Base.getproperty(p::UnsafePtr{T}, n::Symbol) where {T} =
        UnsafePtr(_fieldtype(T, Val(n)), pointer(p) + _fieldoffset(T, Val(n)))

    Base.setproperty!(p::UnsafePtr, n::Symbol, x) =
        error("setting properties not supported; maybe you meant `p.$n[] = ...`")

    Base.propertynames(p::UnsafePtr{T}) where {T} =
        fieldnames(T)

    Base.iterate(p0::UnsafePtr{T}, p::UnsafePtr{T}=p0) where {T} =
        p[], p+1

    Base.:+(p::UnsafePtr{T}, o::Integer) where {T} = UnsafePtr(pointer(p) + o*sizeof(T))
    Base.:+(o::Integer, p::UnsafePtr{T}) where {T} = UnsafePtr(o*sizeof(T) + pointer(p))

    Base.:-(p::UnsafePtr{T}, o::Integer) where {T} = UnsafePtr(pointer(p) - o*sizeof(T))
    Base.:-(o::Integer, p::UnsafePtr{T}) where {T} = UnsafePtr(o*sizeof(T) - pointer(p))

    function Base.:-(p::UnsafePtr{T}, q::UnsafePtr{T}) where {T}
        q, r = fldmod(pointer(p) - pointer(q), sizeof(T))
        r == 0 || error("pointers to T must be a multiple of sizeof(T) apart")
        q
    end

    @generated function _fieldindex(::Type{T}, ::Val{i}) where {T,i}
        if i isa Integer
            1 ≤ i ≤ fieldcount(T) || error("invalid field index $i for $T")
            return i
        elseif i isa Symbol
            j = findfirst(==(i), fieldnames(T))
            j isa Integer || error("invalid field name $i for $T")
            return j
        else
            error("expected an integer or symbol")
        end
    end

    @generated _fieldoffset(::Type{T}, ::Val{i}) where {T,i} =
        fieldoffset(T, _fieldindex(T, Val(i)))

    @generated _fieldtype(::Type{T}, ::Val{i}) where {T,i} =
        fieldtype(T, _fieldindex(T, Val(i)))

end # module
