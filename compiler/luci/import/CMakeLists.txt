file(GLOB_RECURSE SOURCES "src/*.cpp")
file(GLOB_RECURSE TESTS "src/*.test.cpp")
list(REMOVE_ITEM SOURCES ${TESTS})

if (NOT LUCI_LIBRARY_TYPE)
  set(LUCI_LIBRARY_TYPE "SHARED")
endif(NOT LUCI_LIBRARY_TYPE)

add_library(luci_import ${LUCI_LIBRARY_TYPE} ${SOURCES})
target_include_directories(luci_import PRIVATE src)
target_include_directories(luci_import PUBLIC include)
target_link_libraries(luci_import PUBLIC luci_lang)
target_link_libraries(luci_import PUBLIC luci_profile)
target_link_libraries(luci_import PUBLIC luci_plan)
target_link_libraries(luci_import PUBLIC mio_circle04)
target_link_libraries(luci_import PRIVATE luci_env)
target_link_libraries(luci_import PRIVATE luci_log)
target_link_libraries(luci_import PRIVATE luci_logex)
target_link_libraries(luci_import PRIVATE nncc_common)
target_link_libraries(luci_import PRIVATE locop)
target_link_libraries(luci_import PRIVATE foder)
target_link_libraries(luci_import PRIVATE oops)
target_link_libraries(luci_import PRIVATE mio_circle04_helper)
install(TARGETS luci_import DESTINATION lib)
install(DIRECTORY include/ DESTINATION include
        FILES_MATCHING PATTERN "*.h")

if(NOT ENABLE_TEST)
  return()
endif(NOT ENABLE_TEST)

nnas_find_package(GTest REQUIRED)

GTest_AddTest(luci_import_test ${TESTS})
target_include_directories(luci_import_test PRIVATE src)
target_link_libraries(luci_import_test luci_import)
