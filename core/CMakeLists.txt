# Hanagram çekirdeği — tek kaynak, beş platform
#
# Hedefler:
#   hanagram_core   : statik kitaplık (iOS, test)
#   hanagram        : paylaşımlı kitaplık (Android .so, Windows .dll, macOS .dylib)
#   hanagram_tests  : cihazsız testler
cmake_minimum_required(VERSION 3.20)
project(hanagram VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(HG_SOURCES
  src/util/json.cpp
  src/kernel/id.cpp
  src/kernel/store.cpp
  src/kernel/runtime.cpp
  src/algo/interest.cpp
  src/algo/ranker.cpp
  src/algo/learner.cpp
  src/domain/identity/invite.cpp
  src/domain/social/messaging.cpp
  src/domain/business/ad.cpp
  src/domain/business/appointment.cpp
  src/domain/business/customer.cpp
  src/domain/business/product.cpp
  src/domain/business/sale.cpp
  src/domain/media/media.cpp
  src/api/identity.cpp
  src/api/social.cpp
  src/api/admin.cpp
  src/api/messaging.cpp
  src/api/business.cpp
  src/api/media.cpp
  src/ffi/api.cpp
)

# ——— Statik kitaplık ———
add_library(hanagram_core STATIC ${HG_SOURCES})
target_include_directories(hanagram_core
  PUBLIC  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Uyarılar hata sayılır: çekirdek kodu temiz olmak zorunda.
if(MSVC)
  target_compile_options(hanagram_core PRIVATE /W4 /permissive-)
else()
  target_compile_options(hanagram_core PRIVATE
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wno-sign-conversion)
endif()

# ——— Paylaşımlı kitaplık (Android/Windows/macOS/Linux) ———
add_library(hanagram SHARED ${HG_SOURCES})
target_include_directories(hanagram
  PUBLIC  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)
target_compile_definitions(hanagram PRIVATE HANAGRAM_BUILD_SHARED)
set_target_properties(hanagram PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
  OUTPUT_NAME "hanagram"
)

# ——— Testler ———
option(HG_BUILD_TESTS "Testleri derle" ON)
if(HG_BUILD_TESTS)
  enable_testing()
  add_executable(hanagram_tests
    tests/main.cpp
    tests/test_json.cpp
    tests/test_store.cpp
    tests/test_invite.cpp
    tests/test_interest.cpp
    tests/test_ranker.cpp
    tests/test_learner.cpp
    tests/test_api.cpp
    tests/test_messaging.cpp
    tests/test_appointment.cpp
    tests/test_customer.cpp
    tests/test_product.cpp
    tests/test_sale.cpp
    tests/test_ad.cpp
    tests/test_media.cpp
    tests/test_business.cpp
  )
  target_link_libraries(hanagram_tests PRIVATE hanagram_core)
  target_include_directories(hanagram_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/tests
  )
  add_test(NAME core COMMAND hanagram_tests)
endif()
