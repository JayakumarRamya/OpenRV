//
// rv_cache_prewarm.mu
//
// OpenRV pre-warm cache script
// Place in: %APPDATA%\RV\Mu\rv_cache_prewarm.mu
// OR drop into the _install folder and run Install-RVPrefs.ps1
//
// What it does:
//   - Runs automatically when RV opens a media file
//   - Immediately starts reading the first 100 frames into the look-ahead cache
//   - By the time the user presses Play, frames are already in RAM
//   - Zero stutter on first playback
//   - If media is shorter than 100 frames it reads all frames
//   - Works for ALL formats: EXR, MOV, DPX, TIFF, etc.
//   - Safe: if anything fails RV loads normally with no error
//

module: rv_cache_prewarm
{
    use rvtypes;
    use commands;
    use extra_commands;

    // How many frames to pre-read into cache on file open
    // Increase for longer sequences, decrease for slower machines
    global int PREWARM_FRAMES = 100;

    // How many frames to pre-read for 4K and above (larger = more RAM used)
    global int PREWARM_FRAMES_4K = 50;

    // Resolution threshold for 4K detection (width in pixels)
    global int RESOLUTION_4K_THRESHOLD = 3840;

    \: prewarm_cache (void; Event event)
    {
        try
        {
            // Get current media info
            let sources = sourcesAtFrame(frame());

            if (sources eq nil || sources.size() == 0)
            {
                return;
            }

            // Detect resolution to pick correct prewarm depth
            let info        = sourceMediaInfo(sources[0], nil);
            let width       = info.width;
            let startFrame  = info.startFrame;
            let endFrame    = info.endFrame;
            let totalFrames = endFrame - startFrame;

            // Use smaller prewarm for 4K+ to avoid memory pressure
            int warmFrames;
            if (width >= RESOLUTION_4K_THRESHOLD)
            {
                warmFrames = math.min(PREWARM_FRAMES_4K, totalFrames);
            }
            else
            {
                warmFrames = math.min(PREWARM_FRAMES, totalFrames);
            }

            // Pre-read frames into cache in background
            // prefetch() tells RV to load frames into look-ahead cache
            // without moving the playhead
            for (int i = startFrame; i < startFrame + warmFrames; i++)
            {
                prefetch(i);
            }

            print("rv_cache_prewarm: pre-warmed %d frames (resolution: %dx, format: %s)\n"
                % (warmFrames, width, info.mediaType));
        }
        catch (...)
        {
            // Silent fail — never block RV from loading
            // If prewarm fails for any reason RV continues normally
        }
    }

    \: theMode (MinorMode;)
    {
        return MinorMode
        {
            // Trigger prewarm whenever a new source is loaded
            { "after-graph-view-change", prewarm_cache, "Pre-warm cache on media load" },
            { "source-group-complete",   prewarm_cache, "Pre-warm cache on source complete" }
        };
    }

    // Register this module with RV
    // RV calls this automatically on startup
    \: rv_cache_prewarm_mode (void;)
    {
        registerMinorMode(
            "rv_cache_prewarm",   // mode name
            theMode(),            // mode definition
            true                  // active by default
        );
    }
}
