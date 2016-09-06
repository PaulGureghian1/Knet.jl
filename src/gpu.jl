const libknet8  = Libdl.find_library(["libknet8"], [Pkg.dir("Knet/src")])

# This does not compile:
# function __init__()
#     if gpulibs()
#         gpu(pickgpu())
#     end
# end

let GPU=-1, cublashandles=Dict()
    global gpu
    global cublashandle
    gpu()=GPU
    gpu(b::Bool)=gpu(b ? pickgpu() : -1)
    function gpu(i::Int)
        global GPU = i
        if i >= 0
            CUDArt.device(i)
            cublashandle = get!(cublasCreate, cublashandles, i)
        else
            cublashandle = nothing
        end
    end
end

function gpulibs()
    libs = true
    lpath = [Pkg.dir("Knet/src")]
    for l in ("libknet8", "libcuda", "libcudart", "libcublas","libcudnn")
        isempty(Libdl.find_library([l], lpath)) && (warn("Cannot find $l");libs=false)
    end
    # TODO: eliminate these dependencies:
    for p in ("CUDArt",) # , "CUBLAS", "CUDNN")
        isdir(Pkg.dir(p)) || (warn("Cannot find $p");libs=false)
    end
    return libs
end

function gpucount()
    ptr=Int32[0]
    gpustat=ccall((:cudaGetDeviceCount,:libcudart),Int32,(Ptr{Cint},),ptr)
    if gpustat == 0
        return Int(ptr[1])
    else
        return 0
    end
end

function gpufree()
    mfree=Csize_t[1]
    mtotal=Csize_t[1]
    ccall((:cudaMemGetInfo,:libcudart),Cint,(Ptr{Csize_t},Ptr{Csize_t}),mfree,mtotal)
    nbytes=convert(Int,mfree[1])
end

function pickgpu()
    pick = free = -1
    if !isempty(libcudart)
        for i=0:gpucount()-1
            CUDArt.device(i)
            ifree = gpufree()
            if ifree > free
                pick = i
                free = ifree
            end
        end
    end
    return pick
end

function gpuinfo(msg="")
    nbytes = gpufree()
    narray=length(CUDArt.cuda_ptrs)
    print("$msg ")
    println((nbytes,meminfo()...,:cuda_ptrs,narray))
end

function cublasCreate()
    handleP = Ptr{Void}[0]
    ret = ccall((:cublasCreate_v2, libcublas), UInt32, (Ptr{Ptr{Void}},), handleP)
    ret==0 || error("Could not create cublasHandle: $ret")
    handle = handleP[1]
    atexit(()->cublascheck(ccall((:cublasDestroy_v2, libcublas), UInt32, (Ptr{Void},), handle)))
    return handle
end

