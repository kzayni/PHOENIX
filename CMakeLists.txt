cmake_minimum_required(VERSION 3.20)

project(PHOENIX VERSION 0.1.0 LANGUAGES CXX)

add_library(PhoenixCore STATIC
    PhoenixCore/src/c_api.cpp
    PhoenixCore/src/geometry/CircularCylinder.cpp
    PhoenixCore/src/geometry/NACA4Airfoil.cpp
    PhoenixCore/src/geometry/NACA5Airfoil.cpp
    PhoenixCore/src/geometry/SurfaceGeometry2D.cpp
)
add_library(PHOENIX::Core ALIAS PhoenixCore)

target_compile_features(PhoenixCore PUBLIC cxx_std_20)
target_include_directories(PhoenixCore
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/PhoenixCore/include>
        $<INSTALL_INTERFACE:include>
)
set_target_properties(PhoenixCore PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(MSVC)
    target_compile_options(PhoenixCore PRIVATE /W4 /permissive-)
else()
    target_compile_options(PhoenixCore PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_executable(phoenix CLI/main.cpp)
target_compile_features(phoenix PRIVATE cxx_std_20)
target_link_libraries(phoenix PRIVATE PHOENIX::Core)

include(CTest)
if(BUILD_TESTING)
    add_executable(PhoenixCoreTests Tests/Cpp/GeometryTests.cpp)
    target_compile_features(PhoenixCoreTests PRIVATE cxx_std_20)
    target_link_libraries(PhoenixCoreTests PRIVATE PHOENIX::Core)
    add_test(NAME PhoenixCore.Geometry COMMAND PhoenixCoreTests)
    add_test(
        NAME PhoenixCLI.NACA
        COMMAND phoenix geometry naca --profile 0012 --points 256
                --output ${CMAKE_CURRENT_BINARY_DIR}/naca0012.csv
    )
    add_test(
        NAME PhoenixCLI.NACA5
        COMMAND phoenix geometry naca --profile 23012 --points 256
                --output ${CMAKE_CURRENT_BINARY_DIR}/naca23012.csv
    )
    add_test(
        NAME PhoenixCLI.Cylinder
        COMMAND phoenix geometry cylinder --radius 0.5 --points 256
                --output ${CMAKE_CURRENT_BINARY_DIR}/cylinder.csv
    )
    add_test(
        NAME PhoenixCLI.InvalidInput
        COMMAND phoenix geometry naca --profile 0000 --points 256
                --output ${CMAKE_CURRENT_BINARY_DIR}/invalid.csv
    )
    set_tests_properties(PhoenixCLI.InvalidInput PROPERTIES WILL_FAIL TRUE)
endif()
