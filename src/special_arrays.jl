export UnitVector, CorrCholeskyFactor

"""
    (y, r, ℓ) = $SIGNATURES

Given ``x ∈ ℝ`` and ``0 ≤ r ≤ 1``, return `(y, r′)` such that

1. ``y² + r′² = r²``,

2. ``y: |y| ≤ r`` is mapped with a bijection from `x`.

`ℓ` is the log Jacobian (whether it is evaluated depends on `flag`).
"""
@inline function l2_remainder_transform(flag::LogJacFlag, x, r)
    z = 2*logistic(x) - 1
    (z * √r, r*(1 - abs2(z)),
     flag isa NoLogJac ? flag : log(2) + logistic_logjac(x) + 0.5*log(r))
end

"""
    (x, r′) = $SIGNATURES

Inverse of [`l2_remainder_transform`](@ref) in `x` and `y`.
"""
@inline l2_remainder_inverse(y, r) = logit((y/√r+1)/2), r-abs2(y)


"""
    UnitVector(n)

Transform `n-1` real numbers to a unit vector of length `n`, under the
Euclidean norm.
"""
struct UnitVector <: VectorTransform
    n::Int
    function UnitVector(n::Int)
        @argcheck n ≥ 1 "Dimension should be positive."
        new(n)
    end
end

"""
$(SIGNATURES)

Return a transformation that transforms `n - 1` real numbers to a unit vector
(under Euclidean norm).
"""
to_unitvec(n) = UnitVector(n)

dimension(t::UnitVector) = t.n - 1

function transform_with(flag::LogJacFlag, t::UnitVector, x::RealVector{T}) where T
    @unpack n = t
    r = one(T)
    y = Vector{T}(undef, n)
    ℓ = logjac_zero(flag, T)
    index = firstindex(x)
    @inbounds for i in 1:(n - 1)
        xi = x[index]
        index += 1
        y[i], r, ℓi = l2_remainder_transform(flag, xi, r)
        ℓ += ℓi
    end
    y[end] = √r
    y, ℓ
end

inverse_eltype(t::UnitVector, y::RealVector) = float(eltype(y))

function inverse!(x::RealVector, t::UnitVector, y::RealVector)
    @unpack n = t
    @argcheck length(y) == n
    @argcheck length(x) == n - 1
    r = one(eltype(y))
    xi = firstindex(x)
    @inbounds for yi in axes(y, 1)[1:(end-1)]
        x[xi], r = l2_remainder_inverse(y[yi], r)
        xi += 1
    end
    x
end


# correlation cholesky factor

"""
    CorrCholeskyFactor(n)

Cholesky factor of a correlation matrix of size `n`.
"""
struct CorrCholeskyFactor <: VectorTransform
    n::Int
    function CorrCholeskyFactor(n)
        @argcheck n ≥ 1 "Dimension should be positive."
        new(n)
    end
end

"""
$(SIGNATURES)

Return a transformation that transforms real numbers to an ``n×n``
upper-triangular matrix `Ω`, such that `Ω'*Ω` is a correlation matrix (positive
definite, with unit diagonal).
"""
to_corr_cholesky(n) = CorrCholeskyFactor(n)

dimension(t::CorrCholeskyFactor) = unit_triangular_dimension(t.n)

function transform_with(flag::LogJacFlag, t::CorrCholeskyFactor,
                         x::RealVector{T}) where T
    @unpack n = t
    ℓ = logjac_zero(flag, T)
    U = zeros(float(T), n, n)
    index = firstindex(x)
    @inbounds for col in 1:n
        r = one(T)
        for row in 1:(col-1)
            xi = x[index]
            U[row, col], r, ℓi = l2_remainder_transform(flag, xi, r)
            ℓ += ℓi
            index += 1
        end
        U[col, col] = √r
    end
    UpperTriangular(U), ℓ
end

inverse_eltype(t::CorrCholeskyFactor, U::UpperTriangular) = float(eltype(U))

function inverse!(x::RealVector, t::CorrCholeskyFactor, U::UpperTriangular)
    @unpack n = t
    @argcheck size(U, 1) == n
    @argcheck length(x) == dimension(t)
    index = firstindex(x)
    @inbounds for col in 1:n
        r = one(eltype(U))
        for row in 1:(col-1)
            x[index], r = l2_remainder_inverse(U[row, col], r)
            index += 1
        end
    end
    x
end