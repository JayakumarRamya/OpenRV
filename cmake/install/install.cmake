#
# Copyright (C) 2022  Autodesk, Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

MESSAGE(STATUS "Install prefix: \"${CMAKE_INSTALL_PREFIX}\"")

IF(NOT IS_ABSOLUTE ${CMAKE_INSTALL_PREFIX})
  MESSAGE(FATAL_ERROR "${CMAKE_INSTALL_PREFIX} is not an absolute path")
ENDIF()

# ── Collect all files ─────────────────────────────────────────────────────────
FILE(
  GLOB_RECURSE FILES_TO_COPY
  LIST_DIRECTORIES FALSE
  RELATIVE ${RV_APP_ROOT}
  ${RV_APP_ROOT}/*
)

# ── Skip junk files that bloat the install and slow down loading ──────────────
# Only skip in Release — Debug keeps .pdb for stack traces
SET(_SKIP_EXTS "")
IF(CMAKE_BUILD_TYPE STREQUAL "Release")
  LIST(APPEND _SKIP_EXTS ".ilk" ".exp" ".obj" ".iobj" ".ipdb" ".map")
ENDIF()

# Always skip these directories regardless of build type
SET(_SKIP_SEGMENTS "CMakeFiles/" "__pycache__/" ".git/")

SET(_CLEAN_FILES "")
FOREACH(_F ${FILES_TO_COPY})
  # Directory filter
  SET(_SKIP FALSE)
  FOREACH(_SEG ${_SKIP_SEGMENTS})
    STRING(FIND "${_F}" "${_SEG}" _IDX)
    IF(NOT _IDX EQUAL -1)
      SET(_SKIP TRUE)
      BREAK()
    ENDIF()
  ENDFOREACH()
  IF(_SKIP)
    CONTINUE()
  ENDIF()

  # Extension filter (Release only)
  IF(CMAKE_BUILD_TYPE STREQUAL "Release")
    GET_FILENAME_COMPONENT(_EXT "${_F}" EXT)
    STRING(TOLOWER "${_EXT}" _EXT_L)
    IF("${_EXT_L}" IN_LIST _SKIP_EXTS)
      CONTINUE()
    ENDIF()
  ENDIF()

  LIST(APPEND _CLEAN_FILES "${_F}")
ENDFOREACH()

# ── Install loop ──────────────────────────────────────────────────────────────
LIST(LENGTH _CLEAN_FILES FILES_TO_COPY_LENGTH)
SET(CURRENT_FILE_INDEX "0")
SET(FILES_TO_FIX_RPATH "")

FOREACH(
  FILE_TO_COPY
  ${_CLEAN_FILES}
)
  MATH(
    EXPR CURRENT_FILE_INDEX "${CURRENT_FILE_INDEX}+1"
    OUTPUT_FORMAT DECIMAL
  )
  MATH(
    EXPR CURRENT_PERCENTAGE " ${CURRENT_FILE_INDEX} * 100 / ${FILES_TO_COPY_LENGTH} "
    OUTPUT_FORMAT DECIMAL
  )

  BEFORE_COPY(${RV_APP_ROOT}/${FILE_TO_COPY} SHOULD_INSTALL)
  IF(NOT SHOULD_INSTALL)
    MESSAGE(STATUS "${CURRENT_PERCENTAGE}% -- Skipping\t ${RV_APP_ROOT}/${FILE_TO_COPY}")
    CONTINUE()
  ENDIF()

  GET_FILENAME_COMPONENT(DESTINATION_FOLDER ${CMAKE_INSTALL_PREFIX}/${FILE_TO_COPY} DIRECTORY)

  # Only log every 10% to reduce I/O noise — same info, less spam
  MATH(EXPR _MOD "${CURRENT_FILE_INDEX} % 10" OUTPUT_FORMAT DECIMAL)
  IF(_MOD EQUAL 0 OR CURRENT_FILE_INDEX EQUAL 1 OR CURRENT_FILE_INDEX EQUAL FILES_TO_COPY_LENGTH)
    MESSAGE(STATUS "${CURRENT_PERCENTAGE}% -- Installing ${CMAKE_INSTALL_PREFIX}/${FILE_TO_COPY}")
  ENDIF()

  FILE(
    COPY ${RV_APP_ROOT}/${FILE_TO_COPY}
    DESTINATION ${DESTINATION_FOLDER}
    USE_SOURCE_PERMISSIONS
  )

  AFTER_COPY(${CMAKE_INSTALL_PREFIX}/${FILE_TO_COPY} ${RV_APP_ROOT}/${FILE_TO_COPY} FILES_TO_FIX_RPATH)

ENDFOREACH()

POST_INSTALL()
