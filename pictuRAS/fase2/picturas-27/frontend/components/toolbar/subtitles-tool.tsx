import { useState } from "react";
import { Captions } from "lucide-react";
import { ToolbarButton } from "./toolbar-button";
import { useCurrentImage } from "@/providers/project-provider";
import { isVideo } from "@/lib/projects";

/** Project-wide video effect: no imgId, so every video receives captions. */
export default function SubtitlesTool({ disabled }: { disabled: boolean }) {
  const [open, setOpen] = useState(false);
  const currentImage = useCurrentImage();
  return (
    <ToolbarButton
      open={open}
      setOpen={setOpen}
      tool={{ procedure: "subtitles", params: {} }}
      icon={Captions}
      label="Automatic subtitles"
      disabled={disabled}
      previewDisabled={!currentImage || !isVideo(currentImage)}
    >
      <p className="max-w-64 text-xs text-muted-foreground">
        Adds subtitles to every video in this project, in the spoken language.
        Subtitles become part of the exported video. Images and videos without
        speech are left unchanged by this tool.
      </p>
      <p className="max-w-64 pt-2 text-xs text-muted-foreground">
        Save to add to the pipeline, then Apply to process all files.
        Place after trimming or speed changes for best results.
        The first run downloads the speech model and may take longer.
      </p>
    </ToolbarButton>
  );
}
