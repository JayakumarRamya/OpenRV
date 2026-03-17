#
# Copyright (C) 2022  Autodesk, Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# OPTIMIZED VERSION
#   - Filters out build-time junk (.pdb/.ilk/.obj etc.) in Release builds
#   - Skips CMakeFiles / __pycache__ / .git directories
#   - Reduces log spam (prints every 5 % instead of every file)
#   - Preserves all BEFORE_COPY / AFTER_COPY / POST_INSTALL hooks
#   - Preserves USE_SOURCE_PERMISSIONS on every file copy
#

MESSAGE(STATUS "")
MESSAGE(STATUS "=================================================================")
MESSAGE(STATUS " OpenRV Install  |  build-type: ${CMAKE_BUILD_TYPE}")
MESSAGE(STATUS " Source  : ${RV_APP_ROOT}")
MESSAGE(STATUS " Prefix  : ${CMAKE_INSTALL_PREFIX}")
MESSAGE(STATUS "=================================================================")
MESSAGE(STATUS "")

# ── Sanity checks ─────────────────────────────────────────────────────────────
IF(NOT IS_ABSOLUTE ${CMAKE_INSTALL_PREFIX})
  MESSAGE(FATAL_ERROR "CMAKE_INSTALL_PREFIX is not an absolute path: \"${CMAKE_INSTALL_PREFIX}\"")
ENDIF()

IF(NOT EXISTS "${RV_APP_ROOT}")
  MESSAGE(FATAL_ERROR "RV_APP_ROOT does not exist: \"${RV_APP_ROOT}\"")
ENDIF()

# ── Collect every file under RV_APP_ROOT ──────────────────────────────────────
FILE(
  GLOB_RECURSE ALL_FILES
  LIST_DIRECTORIES FALSE
  RELATIVE "${RV_APP_ROOT}"
  "${RV_APP_ROOT}/*"
)

# ── Extension blocklist (Release only) ────────────────────────────────────────
#    These are intermediate build artefacts that should never ship and only
#    slow down the installer / inflate the artifact archive.
SET(_RELEASE_SKIP_EXTS
  ".pdb"    # MSVC program-database (debug symbols)
  ".ilk"    # MSVC incremental-link file
  ".exp"    # export stub
  ".obj"    # compiled object
  ".iobj"   # /GL intermediate object
  ".ipdb"   # /GL intermediate PDB
  ".lib"    # static import lib — kept only if this is a dev install
  ".map"    # linker map file
)

# ── Directory segment blocklist (any build type) ──────────────────────────────
#    Files whose relative path contains any of these strings are skipped.
SET(_SKIP_PATH_SEGMENTS
  "CMakeFiles/"
  "__pycache__/"
  ".git/"
  ".github/"
  "CMakeTmp/"
)

# ── Build the filtered list ───────────────────────────────────────────────────
SET(_FILTERED_FILES "")
SET(_SKIPPED_COUNT  "0")

FOREACH(_FILE ${ALL_FILES})
  # ----- path-segment filter (all build types) --------------------------------
  SET(_PATH_SKIP FALSE)
  FOREACH(_SEG ${_SKIP_PATH_SEGMENTS})
    STRING(FIND "${_FILE}" "${_SEG}" _IDX)
    IF(NOT _IDX EQUAL -1)
      SET(_PATH_SKIP TRUE)
      BREAK()
    ENDIF()
  ENDFOREACH()
  IF(_PATH_SKIP)
    MATH(EXPR _SKIPPED_COUNT "${_SKIPPED_COUNT}+1")
    CONTINUE()
  ENDIF()

  # ----- extension filter (Release only) --------------------------------------
  IF(CMAKE_BUILD_TYPE STREQUAL "Release")
    GET_FILENAME_COMPONENT(_EXT "${_FILE}" EXT)
    STRING(TOLOWER "${_EXT}" _EXT_LOWER)
    IF("${_EXT_LOWER}" IN_LIST _RELEASE_SKIP_EXTS)
      MATH(EXPR _SKIPPED_COUNT "${_SKIPPED_COUNT}+1")
      CONTINUE()
    ENDIF()
  ENDIF()

  LIST(APPEND _FILTERED_FILES "${_FILE}")
ENDFOREACH()

LIST(LENGTH _FILTERED_FILES _TOTAL_FILES)
MESSAGE(STATUS "Files to install : ${_TOTAL_FILES}  (skipped ${_SKIPPED_COUNT} build artefacts)")
MESSAGE(STATUS "")

# ── Install loop ──────────────────────────────────────────────────────────────
SET(_CURRENT_INDEX     "0")
SET(FILES_TO_FIX_RPATH "")
SET(_LAST_LOGGED_PCT   "-1")

FOREACH(_FILE ${_FILTERED_FILES})

  MATH(EXPR _CURRENT_INDEX "${_CURRENT_INDEX}+1" OUTPUT_FORMAT DECIMAL)

  # Compute percentage (avoid division-by-zero if list is empty)
  IF(_TOTAL_FILES GREATER 0)
    MATH(EXPR _PCT "${_CURRENT_INDEX} * 100 / ${_TOTAL_FILES}" OUTPUT_FORMAT DECIMAL)
  ELSE()
    SET(_PCT "100")
  ENDIF()

  # ── Call the project-defined pre-copy hook ──────────────────────────────────
  BEFORE_COPY("${RV_APP_ROOT}/${_FILE}" SHOULD_INSTALL)
  IF(NOT SHOULD_INSTALL)
    CONTINUE()
  ENDIF()

  # ── Resolve destination directory ──────────────────────────────────────────
  GET_FILENAME_COMPONENT(_DEST_DIR "${CMAKE_INSTALL_PREFIX}/${_FILE}" DIRECTORY)

  # ── Log every 5 % boundary (+ first file + last file) ──────────────────────
  MATH(EXPR _PCT_MOD5 "${_PCT} % 5" OUTPUT_FORMAT DECIMAL)
  IF(  _PCT_MOD5 EQUAL 0
    OR _CURRENT_INDEX EQUAL 1
    OR _CURRENT_INDEX EQUAL _TOTAL_FILES)
    IF(NOT _PCT EQUAL _LAST_LOGGED_PCT)
      MESSAGE(STATUS "[${_PCT}%] Installing ${CMAKE_INSTALL_PREFIX}/${_FILE}")
      SET(_LAST_LOGGED_PCT "${_PCT}")
    ENDIF()
  ENDIF()

  # ── Copy the file ───────────────────────────────────────────────────────────
  FILE(
    COPY            "${RV_APP_ROOT}/${_FILE}"
    DESTINATION     "${_DEST_DIR}"
    USE_SOURCE_PERMISSIONS
  )

  # ── Call the project-defined post-copy hook (RPATH fixup etc.) ─────────────
  AFTER_COPY(
    "${CMAKE_INSTALL_PREFIX}/${_FILE}"
    "${RV_APP_ROOT}/${_FILE}"
    FILES_TO_FIX_RPATH
  )

ENDFOREACH()

# ── Final project-defined post-install hook ───────────────────────────────────
POST_INSTALL()

MESSAGE(STATUS "")
MESSAGE(STATUS "=================================================================")
MESSAGE(STATUS " Install complete")
MESSAGE(STATUS "   ${_TOTAL_FILES} files  →  ${CMAKE_INSTALL_PREFIX}")
MESSAGE(STATUS "=================================================================")
MESSAGE(STATUS "")
