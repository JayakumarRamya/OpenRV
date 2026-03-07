name: Build OpenRV Windows

on:
  workflow_dispatch:
    inputs:
      vfx_platform:
        description: 'VFX Platform Year'
        required: true
        default: 'CY2024'
        type: choice
        options:
          - CY2023
          - CY2024
          - CY2025
          - CY2026
      build_type:
        description: 'Build Type'
        required: true
        default: 'Release'
        type: choice
        options:
          - Release
          - Debug

jobs:
  build-windows:
    runs-on: windows-2022
    
    steps:
      - name: Checkout OpenRV
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Upgrade pip
        run: python -m pip install --upgrade pip

      - name: Install Python requirements
        run: pip install -r requirements.txt

      - name: Install system dependencies via Chocolatey
        run: |
          choco install nasm -y
          choco install strawberryperl -y
          choco install winflexbison3 -y
          choco install cmake -y
          choco install ninja -y

      - name: Install Qt
        uses: jurplel/install-qt-action@v3
        with:
          version: '6.5.3'
          host: 'windows'
          target: 'desktop'
          arch: 'win64_msvc2019_64'
          modules: 'qtwebengine'
          cache: 'true'

      - name: Create build directory
        shell: bash
        run: mkdir -p build

      - name: Configure CMake
        shell: bash
        env:
          RV_VFX_PLATFORM: ${{ inputs.vfx_platform }}
          RV_BUILD_TYPE: ${{ inputs.build_type }}
          WIN_PERL: 'c:/Strawberry/perl/bin'
        run: |
          cd build
          cmake .. \
            -G "Visual Studio 17 2022" \
            -A x64 \
            -DCMAKE_BUILD_TYPE=${{ env.RV_BUILD_TYPE }} \
            -DRV_DEPS_QT_LOCATION="${{ env.Qt5_DIR }}/.." \
            -DRV_VFX_PLATFORM=${{ env.RV_VFX_PLATFORM }} \
            -DRV_DEPS_WIN_PERL_ROOT="${{ env.WIN_PERL }}"

      - name: Build OpenRV
        shell: bash
        run: |
          cd build
          cmake --build . --config ${{ inputs.build_type }} --parallel 4

      - name: Run tests
        shell: bash
        continue-on-error: true
        run: |
          cd build
          ctest --test-dir . --output-on-failure -C ${{ inputs.build_type }}

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: OpenRV-Windows-${{ inputs.build_type }}-${{ inputs.vfx_platform }}
          path: build/stage
          if-no-files-found: warn
          retention-days: 30

      - name: Upload build logs on failure
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: OpenRV-Windows-BuildLogs-${{ inputs.build_type }}
          path: |
            build/CMakeFiles/CMakeError.log
            build/CMakeFiles/CMakeOutput.log
          if-no-files-found: ignore
          retention-days: 7
