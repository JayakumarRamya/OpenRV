name: OpenRV Windows

on:
  workflow_dispatch:
    inputs:
      skip_deps_cache:
        type: string
        default: 'false'
      qt5_modules:
        type: string
      full_matrix:
        type: string
        default: 'true'
      run_debug:
        type: string
        default: 'true'

jobs:

  windows-pr:
    name: 'Windows ${{ matrix.vfx-platform }}
      <${{ matrix.os }}
       msvc=${{ matrix.msvc-component }},
       qt=${{ matrix.qt-version }},
       python=${{ matrix.python-version }},
       cmake=${{ matrix.cmake-version }},
       arch=${{ matrix.arch-type }},
       config=${{ matrix.build-type }}>'

    strategy:
      fail-fast: false
      matrix:
        include:
          - os: "windows-2022"
            arch-type: "x86_64"
            build-type: "Release"
            qt-version: "6.5.3"
            python-version: "3.11"
            cmake-version: "3.31.6"
            vfx-platform: "CY2024"
            msvc-component: "14.40.17.10.x86.x64"
            msvc-compiler: "14.40.33807"

    runs-on: ${{ matrix.os }}
    env:
      SCCACHE_GHA_ENABLED: false

    steps:
      - name: Check out repository code
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
        with:
          submodules: recursive

      - uses: ./.github/actions/build-windows
        with:
          build-type: ${{ matrix.build-type }}
          qt-version: ${{ matrix.qt-version }}
          python-version: ${{ matrix.python-version }}
          cmake-version: ${{ matrix.cmake-version }}
          vfx-platform: ${{ matrix.vfx-platform }}
          msvc-component: ${{ matrix.msvc-component }}
          msvc-compiler: ${{ matrix.msvc-compiler }}
          qt5_modules: ${{ inputs.qt5_modules }}

      - name: Upload Windows build
        uses: actions/upload-artifact@v4
        with:
          name: openrv-windows-${{ matrix.build-type }}
          path: _install


  windows-debug:
    if: ${{ inputs.run_debug == 'true' }}

    name: 'Windows ${{ matrix.vfx-platform }}
      <${{ matrix.os }}
       msvc=${{ matrix.msvc-component }},
       qt=${{ matrix.qt-version }},
       python=${{ matrix.python-version }},
       cmake=${{ matrix.cmake-version }},
       arch=${{ matrix.arch-type }},
       config=${{ matrix.build-type }}>'

    strategy:
      fail-fast: false
      matrix:
        include:
          - os: "windows-2022"
            arch-type: "x86_64"
            build-type: "Debug"
            qt-version: "6.5.3"
            python-version: "3.11"
            cmake-version: "3.31.6"
            vfx-platform: "CY2024"
            msvc-component: "14.40.17.10.x86.x64"
            msvc-compiler: "14.40.33807"

    runs-on: ${{ matrix.os }}
    env:
      SCCACHE_GHA_ENABLED: false

    steps:
      - name: Check out repository code
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
        with:
          submodules: recursive

      - uses: ./.github/actions/build-windows
        with:
          build-type: ${{ matrix.build-type }}
          qt-version: ${{ matrix.qt-version }}
          python-version: ${{ matrix.python-version }}
          cmake-version: ${{ matrix.cmake-version }}
          vfx-platform: ${{ matrix.vfx-platform }}
          msvc-component: ${{ matrix.msvc-component }}
          msvc-compiler: ${{ matrix.msvc-compiler }}
          qt5_modules: ${{ inputs.qt5_modules }}

      - name: Upload Windows build
        uses: actions/upload-artifact@v4
        with:
          name: openrv-windows-${{ matrix.build-type }}
          path: _install


  windows-cy2023:
    if: ${{ inputs.full_matrix == 'true' }}

    name: 'Windows ${{ matrix.vfx-platform }}
      <${{ matrix.os }}
       msvc=${{ matrix.msvc-component }},
       qt=${{ matrix.qt-version }},
       python=${{ matrix.python-version }},
       cmake=${{ matrix.cmake-version }},
       arch=${{ matrix.arch-type }},
       config=${{ matrix.build-type }}>'

    strategy:
      fail-fast: false
      matrix:
        include:
          - os: "windows-2022"
            arch-type: "x86_64"
            build-type: "Release"
            qt-version: "5.15.2"
            python-version: "3.10"
            cmake-version: "3.31.6"
            vfx-platform: "CY2023"
            msvc-component: "14.40.17.10.x86.x64"
            msvc-compiler: "14.40.33807"
          - os: "windows-2022"
            arch-type: "x86_64"
            build-type: "Debug"
            qt-version: "5.15.2"
            python-version: "3.10"
            cmake-version: "3.31.6"
            vfx-platform: "CY2023"
            msvc-component: "14.40.17.10.x86.x64"
            msvc-compiler: "14.40.33807"

    runs-on: ${{ matrix.os }}
    env:
      SCCACHE_GHA_ENABLED: false

    steps:
      - name: Check out repository code
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
        with:
          submodules: recursive

      - uses: ./.github/actions/build-windows
        with:
          build-type: ${{ matrix.build-type }}
          qt-version: ${{ matrix.qt-version }}
          python-version: ${{ matrix.python-version }}
          cmake-version: ${{ matrix.cmake-version }}
          vfx-platform: ${{ matrix.vfx-platform }}
          msvc-component: ${{ matrix.msvc-component }}
          msvc-compiler: ${{ matrix.msvc-compiler }}
          qt5_modules: ${{ inputs.qt5_modules }}

      - name: Upload Windows build
        uses: actions/upload-artifact@v4
        with:
          name: openrv-windows-${{ matrix.build-type }}
          path: _install
