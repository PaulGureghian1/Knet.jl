# See if we have gpu support.  This determines whether gpu code is
# loaded, not whether it is used.  The user can control gpu use by
# using the gpu() function.
GPU = true
lpath = [Pkg.dir("Knet/src")]
for l in ("libknet", "libcuda", "libcudart", "libcublas", "libcudnn")
    isempty(Libdl.find_library([l], lpath)) && (warn("Cannot find $l");GPU=false)
end
for p in ("CUDArt", "CUBLAS", "CUDNN")
    isdir(Pkg.dir(p)) || (warn("Cannot find $p");GPU=false)
end
const libcudart = Libdl.find_library(["libcudart"], [])
if GPU
    gpucnt=Int32[0]
    gpuret=ccall((:cudaGetDeviceCount,libcudart),Int32,(Ptr{Cint},),gpucnt)
    (gpucnt == 0 || gpuret != 0) && (warn("No gpu detected");GPU=false)
end

# GPU is a variable indicating the existence of a gpu.
GPU || warn("Using the cpu")

# USEGPU and its controlling function gpu() allows the user 
# to control whether the gpu will be used.
USEGPU = GPU
gpu()=USEGPU
gpu(b::Bool)=(b && !GPU && error("No GPU"); global USEGPU=b)

# Conditionally import gpulibs
macro useifgpu(pkg) if GPU Expr(:using,pkg) end end

# Conditionally evaluate expressions
macro gpu(_ex); if GPU; esc(_ex); end; end

# Additional cuda code
const libknet = Libdl.find_library(["libknet"], [Pkg.dir("Knet/src")])

# For debugging
function gpumem()
    mfree=Csize_t[1]
    mtotal=Csize_t[1]
    ccall((:cudaMemGetInfo,"libcudart.so"),Cint,(Ptr{Csize_t},Ptr{Csize_t}),mfree,mtotal)
    convert(Int,mfree[1])
end

# setseed: Set both cpu and gpu seed. This gets overwritten in curand.jl if gpu available
setseed(n)=srand(n)
