cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "workshop_notes")

cmake_policy(SET CMP0079 NEW)

add_executable(${BINARY_NAME} WIN32
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "flutter_window.cpp"
  "Runner.rc"
  "runner.exe.manifest"
)

apply_standard_settings(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE
  $<$<NOT:$<CONFIG:Debug>>:NOMINMAX>
)

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")

add_dependencies(${BINARY_NAME} flutter_assemble)
