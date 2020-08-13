"""
    UnsafePointers

Provides the [`UnsafePtr`](@ref) type, providing convenient (but unsafe) pointer semantics.
"""
module UnsafePointers

export UnsafePtr

"""
    UnsafePtr{[T]}(r)

A pointer to the contents of `r` which may be a `Ptr`, `Ref`, `Array`, `String` or anything with a `pointer` method. `T` specifies the element type.

It has convenient (but unsafe) semantics:
* `p[]` dereferences the element, and can be assigned to.
* `p[i]` dereferences the `i`th element, assuming the pointer points to an array.
* `p.name` is an `UnsafePtr` to the `name` field of `p[]`. For tuples, `p._n` refers to the `n`th field.
* `p+i` is an `UnsafePtr` to the `i`th next element. `(p+i-1)[]` and `p[i]` are equivalent.
* `p-q` is the number of elements between `p` and `q`, so that `p === q+(p-q)`.
* Iteration yields `p[1]`, `p[2]`, ... forever.
* `Array(p, dims...)` is an array view of contiguous data pointed to by `p` (equivalent to `unsafe_wrap(Array, pointer(p), dims)`).
* `p[idxs]`/`view(p, idxs)` is an array/view of the `i`th element for each `i ∈ idxs`.
* `String(p, [length])` converts `p` to a string (equivalent to `unsafe_string(pointer(p), length)`).

The first four operations have these C equivalents: `*p`, `p[i-1]`, `&(p->name)` and `p+i`.

If the result of dereferencing is pointer-like then an `UnsafePtr` is returned instead (see [`doautowrap`](@ref)). Use `p[!,i]` or `unsafe_load(p,i)` to get the original value.

# Safety

It is the caller's responsibility to ensure that the pointer remains valid, e.g. by ensuring that `r` is not garbage collected.

You will likely crash Julia if you assign to a non-bitstype value.

# Example

Here we access and modify the individual fields of a (mutable) reference to a (immutable) named tuple.

```julia
r = Ref((a=1, b=(2, 3)))
@show r[]            # (a = 1, b = (2, 3))
p = UnsafePtr(r)
p.a[] = 99
p.b._2[] *= 10
@show r[]            # (a = 99, b = (2, 30))
@show Array(p.a, 3)  # [99, 2, 30]
```
"""
struct UnsafePtr{T} <: Ref{T}
    ptr :: Ptr{T}
    UnsafePtr{T}(p::Ptr{T}) where {T} = new{T}(p)
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
Base.convert(::Type{UnsafePtr}, p::Ptr) = UnsafePtr(p)
Base.convert(::Type{UnsafePtr{T}}, p::Ptr) where {T} = UnsafePtr{T}(p)
Base.convert(::Type{UnsafePtr}, p) = convert(UnsafePtr, convert(Ptr, p))
Base.convert(::Type{UnsafePtr{T}}, p) where {T} = convert(UnsafePtr{T}, convert(Ptr{T}, p))

Base.unsafe_convert(P::Type{<:Union{Ptr,UnsafePtr}}, p::UnsafePtr) =
    Base.unsafe_convert(P, pointer(p))

UnsafePtr{T}(p::Ptr) where {T} = UnsafePtr{T}(Ptr{T}(p))
UnsafePtr{T}(p::UnsafePtr) where {T} = UnsafePtr{T}(pointer(p))
UnsafePtr{T}(p) where {T} = UnsafePtr{T}(UnsafePtr(p))

UnsafePtr(p::Ptr{T}) where {T} = UnsafePtr{T}(p)
UnsafePtr(p::UnsafePtr) = p
UnsafePtr(r::Ref) = UnsafePtr(Base.unsafe_convert(Ptr{eltype(r)}, r))
UnsafePtr(x) = UnsafePtr(pointer(x))

Base.unsafe_load(p::UnsafePtr, i::Integer=1) =
    unsafe_load(pointer(p), i)

Base.unsafe_store!(p::UnsafePtr, x, i::Integer=1) =
    unsafe_store!(pointer(p), x, i)

"""
    doautowrap(T)

True if `p[]` should return a `UnsafePtr` whenever `p::UnsafePtr{T}`.
"""
doautowrap(::Type) = false
doautowrap(::Type{<:Ptr}) = true
doautowrap(::Type{Cstring}) = true
doautowrap(::Type{Cwstring}) = true

Base.getindex(p::UnsafePtr{T}, i::Integer=1) where {T} =
    doautowrap(T) ? UnsafePtr(unsafe_load(p, i)) : unsafe_load(p, i)

Base.getindex(p::UnsafePtr, ::typeof(!), i::Integer=1) =
    unsafe_load(p, i)

Base.getindex(p::UnsafePtr, idxs::AbstractArray{<:Integer}) =
    [getindex(p, i) for i in idxs]

Base.getindex(p::UnsafePtr, R, idxs::AbstractArray{<:Integer}) =
    [getindex(p, R, i) for i in idxs]

Base.getindex(p::UnsafePtr, idxs::AbstractVector{Bool}) =
    [getindex(p, i) for (i,b) in enumerate(idxs) if b]

Base.getindex(p::UnsafePtr, R, idxs::AbstractVector{Bool}) =
    [getindex(p, R, i) for (i,b) in enumerate(idxs) if b]

Base.setindex!(p::UnsafePtr{T}, x, i::Integer=1) where {T} =
    unsafe_store!(p, convert(T, x), i)

Base.setindex!(p::UnsafePtr{T}, x, ::typeof(!), i::Integer=1) where {T} =
    unsafe_store!(p, Base.unsafe_convert(T, x), i)

_getproperty(p::UnsafePtr{T}, n::Val) where {T} =
    UnsafePtr{_fieldtype(T, n)}(pointer(p) + _fieldoffset(T, n))

Base.getproperty(p::UnsafePtr, n::Val) = _getproperty(p, n)
Base.getproperty(p::UnsafePtr, n::Symbol) = _getproperty(p, Val(n))
Base.getproperty(p::UnsafePtr, n::Integer) = _getproperty(p, Val(Int(n)))

_setproperty!(p::UnsafePtr, ::Val{name}, x) where {name} =
    error("setting properties not supported; maybe you meant `p.$name[] = ...`")

Base.setproperty!(p::UnsafePtr, n::Val, x) = _setproperty!(p, n, x)
Base.setproperty!(p::UnsafePtr, n::Symbol, x) = _setproperty!(p, Val(n), x)
Base.setproperty!(p::UnsafePtr, n::Integer, x) = _setproperty!(p, Val(Int(n)), x)

Base.propertynames(p::UnsafePtr{T}, private=false) where {T} = fieldnames(T)

Base.iterate(p0::UnsafePtr{T}, p::UnsafePtr{T}=p0) where {T} = p[], p+1

Base.IteratorSize(::Type{<:UnsafePtr}) = Base.IsInfinite()

Base.:+(p::UnsafePtr{T}, o::Integer) where {T} = UnsafePtr(pointer(p) + o*sizeof(T))
Base.:+(o::Integer, p::UnsafePtr{T}) where {T} = UnsafePtr(o*sizeof(T) + pointer(p))

Base.:-(p::UnsafePtr{T}, o::Integer) where {T} = UnsafePtr(pointer(p) - o*sizeof(T))

function Base.:-(p::UnsafePtr{T}, q::UnsafePtr{T}) where {T}
    q, r = fldmod(pointer(p) - pointer(q), sizeof(T))
    r == 0 || error("pointers to T must be a multiple of sizeof(T) apart")
    q
end

Base.:(==)(p::UnsafePtr, q::UnsafePtr) = pointer(p) == pointer(q)
Base.:(==)(p::UnsafePtr, q::Ptr) = pointer(p) == q
Base.:(==)(p::Ptr, q::UnsafePtr) = p == pointer(q)

# Array(p, dims...) = unsafe_wrap(Array, pointer(p), dims)
(::Type{Array{T,N}})(p::UnsafePtr, dims::Vararg{Integer,N}) where {T,N} = unsafe_wrap(Array, Ptr{T}(pointer(p)), dims)
(::Type{Array{T}})(p::UnsafePtr, dims::Vararg{Integer,N}) where {T,N} = Array{T,N}(p, dims...)
(::Type{Array{_T,N} where _T})(p::UnsafePtr{T}, dims::Vararg{Integer,N}) where {T,N} = Array{T,N}(p, dims...)
Base.Array(p::UnsafePtr{T}, dims::Vararg{Integer,N}) where {T,N} = Array{T,N}(p, dims...)
(::Type{A})(p::UnsafePtr, dims::Tuple{Vararg{Integer}}) where {A<:Array} = A(p, dims...)

# view(p, idxs)
Base.view(p::UnsafePtr, i::Integer=1) = Array(p+(i-1))
Base.view(p::UnsafePtr, i::AbstractUnitRange{<:Integer}) = Array(p+(first(i)-1), length(i))
function Base.view(p::UnsafePtr, i::AbstractVector{<:Integer})
    if isempty(i)
        o = 0
        a = Array(p, 0)
    else
        i0, i1 = extrema(i)
        o = i0 - 1
        a = Array(p+o, i1-o)
    end
    view(a, i.-o)
end

# String(p, [length]) = unsafe_string(pointer(p), length)
(::Type{String})(p::UnsafePtr) = unsafe_string(Ptr{UInt8}(pointer(p)))
(::Type{String})(p::UnsafePtr, length::Integer) = unsafe_string(Ptr{UInt8}(pointer(p)), length)

@generated function _fieldindex(::Type{T}, ::Val{i}) where {T,i}
    if i isa Integer
        1 ≤ i ≤ fieldcount(T) || @goto error
        return i
    elseif T <: Tuple && i isa Symbol
        s = string(i)
        startswith(s, "_") || @goto error
        j = tryparse(Int, s[2:end])
        j isa Int || @goto error
        1 ≤ j ≤ fieldcount(T) || @goto error
        return j
    else
        j = findfirst(==(i), fieldnames(T))
        j isa Integer || @goto error
        return j
    end
    @label error
    :(error($("invalid field name $(repr(i)) for $(repr(T))")))
end

@generated _fieldoffset(::Type{T}, ::Val{i}) where {T,i} =
    try
        fieldoffset(T, _fieldindex(T, Val(i)))
    catch err
        :(throw($err))
    end

@generated _fieldtype(::Type{T}, ::Val{i}) where {T,i} =
    try
        fieldtype(T, _fieldindex(T, Val(i)))
    catch err
        :(throw($err))
    end

end # module
