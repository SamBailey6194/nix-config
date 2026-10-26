{ config, pkgs, ... }:

let
  handbrakePgsPatch = pkgs.writeText "handbrake-ffmpeg-8.1.3-pgs.patch" ''
    --- a/contrib/ffmpeg/A15-lavc-pgssubdec-Add-graphic-plane-and-cropping.patch
    +++ b/contrib/ffmpeg/A15-lavc-pgssubdec-Add-graphic-plane-and-cropping.patch
    @@ -600,7 +600,7 @@
          palette = find_palette(ctx->presentation.palette_id, &ctx->palettes);
          if (!palette) {
              // Missing palette.  Should only happen with damaged streams.
    -@@ -528,57 +616,128 @@ static int display_end_segment(AVCodecContext *avctx, AVSubtitle *sub,
    +@@ -528,65 +616,133 @@ static int display_end_segment(AVCodecContext *avctx, AVSubtitle *sub,
              avsubtitle_free(sub);
              return AVERROR_INVALIDDATA;
          }
    @@ -612,6 +612,16 @@
     -            return AVERROR(ENOMEM);
     -        sub->rects[sub->num_rects++] = rect;
     -        rect->type = SUBTITLE_BITMAP;
    +-
    +-        /* Allocate the palette now so that the error paths below, which
    +-         * leave the rect empty, still hand consumers a complete bitmap
    +-         * rect rather than one with a NULL palette. */
    +-        rect->nb_colors = 256;
    +-        rect->data[1]   = av_mallocz(AVPALETTE_SIZE);
    +-        if (!rect->data[1])
    +-            return AVERROR(ENOMEM);
    +-        if (!ctx->forced_subs_only || ctx->presentation.objects[i].composition_flag & 0x40)
    +-            memcpy(rect->data[1], palette->clut, rect->nb_colors * sizeof(uint32_t));
     -
     -        /* Process bitmap */
     -        object = find_object(ctx->presentation.objects[i].id, &ctx->objects);
    @@ -753,8 +763,6 @@
     -                continue;
                  }
              }
    --        /* Allocate memory for colors */
    --        rect->nb_colors = 256;
     +        // Export graphic plane content with latest palette
     +        rect = av_memdup(gp_rect, sizeof(*gp_rect));
     +        if (!rect)
    @@ -769,10 +777,15 @@
     +
     +        // Allocate memory for colors
     +        rect->nb_colors = AVPALETTE_COUNT;
    -         rect->data[1]   = av_mallocz(AVPALETTE_SIZE);
    -         if (!rect->data[1])
    -             return AVERROR(ENOMEM);
    -@@ -641,14 +800,7 @@ static int decode(AVCodecContext *avctx, AVSubtitle *sub,
    ++        rect->data[1]   = av_mallocz(AVPALETTE_SIZE);
    ++        if (!rect->data[1])
    ++            return AVERROR(ENOMEM);
    ++        if (!ctx->forced_subs_only || ctx->presentation.objects[i].composition_flag & 0x40)
    ++            memcpy(rect->data[1], palette->clut, rect->nb_colors * sizeof(uint32_t));
    +     }
    +     return 1;
    + }
    +@@ -643,14 +800,7 @@ static int decode(AVCodecContext *avctx, AVSubtitle *sub,
                  ret = parse_presentation_segment(avctx, buf, segment_length, sub->pts);
                  break;
              case WINDOW_SEGMENT:
  '';
in
{
  # Media playback and viewing
  # Video players, image viewers, music players

  nixpkgs.overlays = [
    (final: prev: {
      # HandBrake 1.11.2's PGS patch predates FFmpeg 8.1.3's palette allocation
      # change. Rebase its patch while retaining palette allocation for every
      # exported rectangle. Remove when nixpkgs updates the bundled patches.
      handbrake = prev.handbrake.override {
        applyPatches = args: prev.applyPatches (args // {
          patches = (args.patches or [ ]) ++ [
            handbrakePgsPatch
          ];
        });
      };
    })
  ];

  environment.systemPackages = with pkgs; [
    # Video players
    vlc                # VLC media player
    mpv                # Lightweight video player

    # Image viewers
    imv                # Wayland image viewer
    # feh              # X11 image viewer
    # gwenview         # KDE image viewer

    # Image editors (lightweight)
    gimp               # GNU Image Manipulation Program
    # inkscape         # Vector graphics editor

    # PDF viewers
    zathura            # Lightweight PDF viewer
    # evince           # GNOME PDF viewer

    # Music players
    spotify            # Spotify music streaming
    # rhythmbox        # GNOME music player
    # clementine       # Qt music player

    # Disc ripping and transcoding (STORAGE-AND-MEDIA-ARCHITECTURE.md)
    makemkv            # Lossless optical disc rip to MKV (unfree)
    handbrake          # H.264/H.265 transcoding for Jellyfin direct play

    # Audio tools
    audacity           # Audio editing
    # ardour           # Digital audio workstation

    # Screenshot tools (already in base, but noted here)
    # grim, slurp, swappy are in desktop/hyprland
  ];

  # MakeMKV talks to optical drives through SCSI generic devices (/dev/sg*)
  boot.kernelModules = [ "sg" ];
}
