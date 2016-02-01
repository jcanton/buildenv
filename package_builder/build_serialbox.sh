#!/usr/bin/env bash

exitError()
{
    echo "ERROR $1: $3" 1>&2
    echo "ERROR     LOCATION=$0" 1>&2
    echo "ERROR     LINE=$2" 1>&2
    exit $1
}

TEMP=$@
eval set -- "$TEMP --"
fwd_args=""
target="all"
while true; do
    case "$1" in
        --dir|-d) package_basedir=$2; shift 2;;
        --idir|-i) install_dir=$2; shift 2;;
        --local) install_local="yes"; shift;;
        --tartget|-t) target=$2; shift 2;;
        -- ) shift; break ;;
        * ) fwd_args="$fwd_args $1"; shift ;;
    esac
done

if [[ -z ${package_basedir} ]]; then
    exitError 3221 ${LINENO} "package basedir has to be specified"
fi
if [[ -z ${install_dir} ]]; then
    exitError 3225 ${LINENO} "package install dir has to be specified"
fi

# Setup
echo $@
base_path=$PWD
setupDefaults

if [[ ${install_local} == "yes" ]]; then
    install_path_prefix_="${base_path}/install"
else
    install_path_prefix_="${install_dir}/serialbox"
fi

build_target()
{
    export compiler=$1
    local install_path=$2
    echo "Compiling and installing for $compiler (install path: $install_path)"

    install_args="-i ${install_path}/"


    setFortranEnvironment
    if [ $? -ne 0 ]; then
        exitError 3331 ${LINENO} "Invalid fortran environment"
    fi

    writeModuleList ${base_path}/modules.log loaded "FORTRAN MODULES" ${base_path}/modules_fortran.env
    
    get_fcompiler_cmd fcomp_cmd ${compiler}
    if [[ -z ${fcomp_cmd} ]]; then
        exitError 3332 ${LINENO} "could not set the fortran compiler you are building with"
    fi
    echo "Building for fortran compiler: ${fcomp_cmd}"
    ${package_basedir}/test/build.sh --fcompiler ${fcomp_cmd} ${install_args} -z ${fwd_args}
    if [ $? -ne 0 ]; then
        exitError 3333 "Unable to compile the library with ${compiler}"
    fi
    # Copy module files
    cp modules_fortran.env ${install_path}/modules.env
    unsetFortranEnvironment
}

# Build
if [ "$target" != "all" ]; then
    if [ ${install_local} != "yes" ] ; then
        install_path_prefix_="${install_path_prefix_}/${target}"
    fi
    build_target $target "${install_path_prefix_}"
else
    for c_ in ${compilers[@]}; do
        build_target $c_ "${install_path_prefix_}/$c_/"
    done
fi
