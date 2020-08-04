# UnsafePointers.jl

Convenient (but unsafe) pointer accesses.

This package exports one type, `UnsafePtr{T}`, which behaves identically to a regular `Ptr{T}` but has some convenient (but unsafe) pointer access semantics.

Useful for example for accessing or modifying data exposed by C interfaces through pointers.

## Install

```
pkg> add UnsafePointers
```

## Usage

```julia
UnsafePtr([T,] r)
```

A pointer to the contents of `r` which may be a `Ptr`, `Ref`, or anything with a `pointer` method. `T` specifies the element type.

It has convenient (but unsafe) semantics:
* `p[]` dereferences the element, and can be assigned to.
* `p[i]` dereferences the `i`th element, assuming the pointer points to an array.
* `p.name` is an `UnsafePtr` to the `name` field of `p[]`.
* `p+i` is an `UnsafePtr` to the `i`th next element. `(p+i-1)[]` and `p[i]` are equivalent.
* `p-q` is the number of elements between `p` and `q`, so that `p === q+(p-q)`.
* Iteration yields `p[1]`, `p[2]`, ... forever.

The first four operations have these C equivalents: `*p`, `p[i-1]`, `&(p->name)` and `p+i`.

If the result of dereferencing would be a `Ptr`, an `UnsafePtr` is returned instead. Use `p[Ptr, i]` or `unsafe_load(p, i)` to avoid this.

Use `pointer(p)` to retrieve the underlying `Ptr`.

## Safety

It is the caller's responsibility to ensure that the pointer remains valid, e.g. by ensuring that `r` is not garbage collected.

You will likely crash Julia if you assign to a non-bitstype value.

## Example

Here we access and modify the individual fields of a (mutable) reference to a (immutable) named tuple.

```julia
r = Ref((a=1, b=(c=2, d=3)))
@show r[]       # (a = 1, b = (c = 2, d = 3))
p = UnsafePtr(r)
p.a[] = 99
p.b.d[] *= 10
@show r[]       # (a = 99, b = (c = 2, d = 30))
```
